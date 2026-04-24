# Детализация: Аналитика и отчёты

> **Раздел плана:** 12.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-9 (все предыдущие), Раздел 5 (Дашборд тренера)

---

## 1. Обзор

Аналитика и отчёты — это инструменты тренера для глубокого анализа эффективности группы и отдельных дилеров. Включает расчёт метрик, визуализацию, экспорт и автоматические рекомендации.

---

## 2. Алгоритм расчёта сводной аналитики

### 2.1 Метрики группы

| Метрика | Формула | Описание |
|---------|---------|----------|
| Средняя точность | `AVG(rr.accuracy)` | Средняя точность всех дилеров за период |
| Всего раздач | `COUNT(rr.id)` | Общее количество раундов |
| Всего ошибок | `COUNT(rr.id) WHERE rr.accuracy < 100` | Раунды с хотя бы одной ошибкой |
| Среднее время раунда | `AVG(rr.time_spent_seconds)` | Среднее время принятия решений |
| Активных дилеров | `COUNT(DISTINCT dealer_id) WHERE last_seen > cutoff` | Дилеры, заходившие за период |
| Лучший дилер | `MAX(total_xp)` | Дилер с наибольшим XP |
| Худший дилер | `MIN(accuracy) WHERE rounds >= min_threshold` | Дилер с наименьшей точностью (мин. 10 раундов) |
| Самая частая ошибка | `MODE(error_type)` | Тип ошибки, встречающийся чаще всего |

### 2.2 SQL-запрос для сводной аналитики

```sql
-- server/services/analytics_service.py
class AnalyticsService:
    
    async def get_group_analytics(self, room_code: str, period: str) -> dict:
        """Получить сводную аналитику по группе."""
        
        period_filter = self._get_period_filter(period)
        
        result = db.execute(f"""
            SELECT 
                COUNT(rr.id) AS total_rounds,
                AVG(rr.accuracy) AS avg_accuracy,
                AVG(rr.time_spent_seconds) AS avg_time_per_round,
                COUNT(CASE WHEN rr.accuracy < 100 THEN 1 END) AS total_errors,
                COUNT(DISTINCT rr.dealer_id) AS active_dealers,
                MIN(rr.accuracy) FILTER (WHERE rr.accuracy >= 0) AS min_accuracy,
                MAX(rr.accuracy) AS max_accuracy,
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rr.accuracy) AS median_accuracy
            FROM round_results rr
            JOIN sessions s ON s.id = rr.session_id
            WHERE s.room_id = (SELECT id FROM rooms WHERE room_code = :code)
              AND rr.submitted_at {period_filter}
        """, {"code": room_code}).fetchone()
        
        # Самые частые ошибки
        top_errors = db.execute(f"""
            SELECT error->>'type' AS error_type, COUNT(*) AS count
            FROM round_results rr
            JOIN sessions s ON s.id = rr.session_id,
            jsonb_array_elements(rr.errors) AS error
            WHERE s.room_id = (SELECT id FROM rooms WHERE room_code = :code)
              AND rr.submitted_at {period_filter}
            GROUP BY error->>'type'
            ORDER BY count DESC
            LIMIT 5
        """, {"code": room_code}).fetchall()
        
        # Динамика точности (по дням)
        daily_trend = db.execute(f"""
            SELECT 
                DATE(rr.submitted_at) AS day,
                AVG(rr.accuracy) AS avg_accuracy,
                COUNT(rr.id) AS rounds
            FROM round_results rr
            JOIN sessions s ON s.id = rr.session_id
            WHERE s.room_id = (SELECT id FROM rooms WHERE room_code = :code)
              AND rr.submitted_at {period_filter}
            GROUP BY DATE(rr.submitted_at)
            ORDER BY day
        """, {"code": room_code}).fetchall()
        
        return {
            "summary": {
                "total_rounds": result["total_rounds"],
                "avg_accuracy": round(result["avg_accuracy"], 1),
                "avg_time_per_round": round(result["avg_time_per_round"], 1),
                "total_errors": result["total_errors"],
                "error_rate": round(result["total_errors"] / max(result["total_rounds"], 1) * 100, 1),
                "active_dealers": result["active_dealers"],
                "min_accuracy": round(result["min_accuracy"], 1),
                "max_accuracy": round(result["max_accuracy"], 1),
                "median_accuracy": round(result["median_accuracy"], 1)
            },
            "top_errors": [{"type": e["error_type"], "count": e["count"]} for e in top_errors],
            "daily_trend": [{"date": str(d["day"]), "avg_accuracy": round(d["avg_accuracy"], 1), "rounds": d["rounds"]} for d in daily_trend]
        }
    
    def _get_period_filter(self, period: str) -> str:
        """Получить SQL-фильтр по периоду."""
        filters = {
            "today": ">= CURRENT_DATE",
            "week": ">= NOW() - INTERVAL '7 days'",
            "month": ">= NOW() - INTERVAL '30 days'",
            "all": "IS NOT NULL"
        }
        return filters.get(period, "IS NOT NULL")
```

### 2.3 Метрики отдельного дилера

| Метрика | Формула |
|---------|---------|
| Точность по категориям | `SUM(CASE WHEN correct THEN 1 ELSE 0 END) / COUNT(*) * 100` |
| Лучшая серия | `MAX(consecutive_correct_rounds)` |
| Худшая серия | `MAX(consecutive_error_rounds)` |
| Прогресс (тренд) | `AVG(accuracy за последние 20) - AVG(accuracy за предыдущие 20)` |
| Медианное время | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY time_spent)` |
| Пиковая производительность | `MAX(accuracy) WHERE time_spent <= threshold` |

---

## 3. Структура PDF-отчёта

### 3.1 Шаблон PDF

Генерация через **ReportLab** (Python) или **WeasyPrint** (HTML → PDF).

```python
# server/services/pdf_report_service.py
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, Paragraph, Spacer, Image
from reportlab.lib.styles import getSampleStyleSheet
import io

class PDFReportService:
    
    def generate_dealer_report(self, dealer_id: UUID, period: str) -> bytes:
        """Сгенерировать PDF-отчёт по дилеру."""
        
        # Получить данные
        dealer = self._get_dealer_info(dealer_id)
        stats = self._get_dealer_stats(dealer_id, period)
        
        # Создать PDF
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        styles = getSampleStyleSheet()
        elements = []
        
        # Заголовок
        elements.append(Paragraph("Отчёт по дилеру", styles["Title"]))
        elements.append(Paragraph(f"Дилер: {dealer['display_name']}", styles["Normal"]))
        elements.append(Paragraph(f"Комната: {dealer['room_name']}", styles["Normal"]))
        elements.append(Paragraph(f"Период: {period}", styles["Normal"]))
        elements.append(Spacer(1, 20))
        
        # Сводка
        elements.append(Paragraph("Сводка", styles["Heading2"]))
        summary_data = [
            ["Метрика", "Значение"],
            ["Раундов сыграно", str(stats["total_rounds"])],
            ["Общая точность", f"{stats['accuracy']}%"],
            ["Среднее время", f"{stats['avg_time']} сек"],
            ["Лучшая серия", f"{stats['best_streak']} раундов"],
            ["Достижений", f"{stats['achievements']}"],
        ]
        summary_table = Table(summary_data)
        summary_table.setStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#2196F3")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('GRID', (0, 0), (-1, -1), 1, colors.HexColor("#DDDDDD")),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor("#F5F5F5")])
        ])
        elements.append(summary_table)
        elements.append(Spacer(1, 20))
        
        # Ошибки по категориям
        elements.append(Paragraph("Ошибки по категориям", styles["Heading2"]))
        error_data = [["Категория", "Всего", "Ошибок", "Точность"]]
        for cat in stats["categories"]:
            error_data.append([
                cat["name"],
                str(cat["total"]),
                str(cat["errors"]),
                f"{cat['accuracy']}%"
            ])
        error_table = Table(error_data)
        error_table.setStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#2196F3")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('GRID', (0, 0), (-1, -1), 1, colors.HexColor("#DDDDDD")),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor("#F5F5F5")])
        ])
        elements.append(error_table)
        elements.append(Spacer(1, 20))
        
        # Рекомендации
        elements.append(Paragraph("Рекомендации", styles["Heading2"]))
        for rec in stats["recommendations"]:
            icon = "✅" if rec["priority"] == "good" else "⚠️" if rec["priority"] == "warning" else "🔴"
            elements.append(Paragraph(f"{icon} {rec['message']}", styles["Normal"]))
        
        # Подпись
        elements.append(Spacer(1, 40))
        elements.append(Paragraph("_________________ / Тренер", styles["Normal"]))
        
        # Собрать PDF
        doc.build(elements)
        buffer.seek(0)
        return buffer.getvalue()
```

### 3.2 Структура PDF-отчёта (визуально)

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  ОТЧЁТ ПО ДИЛЕРУ                                    │
│  Baccarat Trainer — Группа А — Утро                │
│  Дата формирования: 12.04.2026                      │
│                                                     │
│  ────────────────────────────────────────────────   │
│                                                     │
│  Дилер: Петрова Мария                               │
│  PIN: •••••1                                        │
│  Период: 01.04.2026 — 12.04.2026                   │
│                                                     │
│  ─── Сводка ───                                     │
│  ┌──────────────────────────────┐                   │
│  │ Метрика          │ Значение  │                   │
│  │ Раундов сыграно  │ 89        │                   │
│  │ Общая точность   │ 78%       │                   │
│  │ Среднее время    │ 28 сек    │                   │
│  │ Лучшая серия     │ 15        │                   │
│  │ Достижений       │ 12        │                   │
│  └──────────────────────────────┘                   │
│                                                     │
│  ─── Ошибки по категориям ───                       │
│  ┌────────────────────────────────────────────┐     │
│  │ Категория        │ Всего │ Ошибок │ Точн.  │     │
│  │ 3-я карта Игрока │ 45    │ 0      │ 100%   │     │
│  │ 3-я карта Банкира│ 42    │ 12     │ 71% ⚠️ │     │
│  │ Выбор победителя │ 89    │ 4      │ 96% ✅ │     │
│  │ Выплата Банкир   │ 30    │ 3      │ 90% ✅ │     │
│  │ Выплата Ничья    │ 15    │ 8      │ 47% 🔴 │     │
│  │ Выплата Пары     │ 8     │ 1      │ 88% ✅ │     │
│  └────────────────────────────────────────────┘     │
│                                                     │
│  ─── Динамика точности (график) ───                 │
│  [Линейный график: точность по дням за период]      │
│                                                     │
│  ─── Рекомендации ───                               │
│  ⚠️ Подтянуть: «3-я карта Банкира» (71%)           │
│  🔴 Подтянуть: «Выплата Ничья» (47%)               │
│  ✅ Отлично: «3-я карта Игрока» (100%)             │
│                                                     │
│  ────────────────────────────────────────────────   │
│                                                     │
│  _________________ /Иванов И./                     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 4. Структура CSV-файла

### 4.1 Формат

```csv
session_id,session_type,round_number,dealer_name,timestamp,accuracy,errors,time_spent,player_third_card,banker_third_card,winner_chosen,winner_correct,payout_correct,lives_remaining
sess-uuid-1,live,1,Новиков Д.,2026-04-12T14:00:10Z,100.0,[],18,true,false,Player,true,true,7
sess-uuid-1,live,2,Новиков Д.,2026-04-12T14:00:28Z,100.0,[],12,true,true,Banker,true,true,7
sess-uuid-1,live,3,Новиков Д.,2026-04-12T14:00:45Z,66.7,[{"type":"banker_third","message":"Банкиру не нужна была третья карта"}],15,false,false,Player,true,true,6
sess-uuid-1,live,1,Петрова М.,2026-04-12T14:00:15Z,100.0,[],22,true,false,Player,true,true,7
...
```

### 4.2 Колонки

| Колонка | Тип | Описание |
|---------|-----|----------|
| session_id | UUID | ID сессии |
| session_type | VARCHAR | live / async |
| round_number | INT | Номер раунда в сессии |
| dealer_name | VARCHAR | Имя дилера |
| timestamp | ISO 8601 | Время завершения раунда |
| accuracy | FLOAT | Точность раунда (0-100) |
| errors | JSON | Массив ошибок |
| time_spent | INT | Время в секундах |
| player_third_card | BOOLEAN | Заказал ли 3-ю карту игроку |
| banker_third_card | BOOLEAN | Заказал ли 3-ю карту банкиру |
| winner_chosen | VARCHAR | Выбранный победитель |
| winner_correct | BOOLEAN | Правильно ли выбрал |
| payout_correct | BOOLEAN | Правильно ли рассчитал выплату |
| lives_remaining | INT | Осталось жизней (если survival) |

### 4.3 Кодировка и форматирование

| Параметр | Значение |
|----------|----------|
| Кодировка | UTF-8 |
| Разделитель | Запятая (`,`) |
| Кавычки | Двойные (`"`) для текстовых полей |
| Дата/время | ISO 8601 (`2026-04-12T14:00:10Z`) |
| Десятичный разделитель | Точка (`.`) |

---

## 5. Алгоритм автоматических рекомендаций

### 5.1 Правила генерации рекомендаций

| Условие | Приоритет | Рекомендация |
|---------|-----------|--------------|
| Точность категории < 60%, попыток >= 5 | 🔴 Критично | "Требуется индивидуальная работа" |
| Точность категории 60-79%, попыток >= 10 | ⚠️ Предупреждение | "Рекомендуется дополнительная практика" |
| Точность категории >= 95%, попыток >= 10 | ✅ Отлично | "Отличная работа!" |
| Среднее время > 30 сек | ⚠️ Предупреждение | "Рекомендуется режим «на время»" |
| Среднее время < 10 сек И точность < 80% | ⚠️ Предупреждение | "Слишком быстро при неточности. Замедлитесь." |
| Тренд точности ↓ > 10% за 20 раундов | ⚠️ Предупреждение | "Возможно усталость. Рекомендуется перерыв." |
| Тренд точности ↑ > 10% за 20 раундов | ✅ Отлично | "Отличный прогресс!" |
| Серия ошибок > 5 подряд | 🔴 Критично | "Серия ошибок. Рекомендуется повторить правила." |
| Лучшая серия > 20 раундов | ✅ Отлично | "Впечатляющая стабильность!" |

### 5.2 Реализация

```python
# server/services/recommendation_service.py
class RecommendationService:
    
    def generate_dealer_recommendations(self, dealer_id: UUID, period: str = "last_30_days") -> list:
        """Сгенерировать рекомендации для дилера."""
        stats = self._get_dealer_detailed_stats(dealer_id, period)
        recommendations = []
        
        # Проверка точности по категориям
        for category, data in stats["category_accuracy"].items():
            if data["total"] < 5:
                continue  # Недостаточно данных
            
            if data["accuracy"] < 60:
                recommendations.append({
                    "priority": "critical",
                    "type": "individual_training",
                    "category": category,
                    "message": f"Критическая точность в «{category}» ({data['accuracy']}%). Требуется индивидуальная работа.",
                    "suggested_action": f"30 раздач с фокусом на «{category}»",
                    "create_task_template": f"category_focus:{category}"
                })
            elif data["accuracy"] < 80:
                recommendations.append({
                    "priority": "warning",
                    "type": "practice",
                    "category": category,
                    "message": f"Есть проблемы с «{category}» ({data['accuracy']}%). Рекомендуется практика.",
                    "suggested_action": f"20 раздач с фокусом на «{category}»",
                    "create_task_template": f"category_focus:{category}"
                })
            elif data["accuracy"] >= 95:
                recommendations.append({
                    "priority": "good",
                    "type": "praise",
                    "category": category,
                    "message": f"Отличная работа с «{category}» ({data['accuracy']}%)!"
                })
        
        # Проверка скорости
        avg_time = stats["avg_time_per_round"]
        if avg_time > 30:
            recommendations.append({
                "priority": "warning",
                "type": "speed",
                "message": f"Медленная скорость ({avg_time}с/раунд). Рекомендуется режим «на время».",
                "suggested_action": "30 раздач с ограничением времени"
            })
        elif avg_time < 10 and stats["accuracy"] < 80:
            recommendations.append({
                "priority": "warning",
                "type": "slow_down",
                "message": f"Быстрая игра ({avg_time}с) при точности {stats['accuracy']}%. Рекомендуется замедлиться.",
                "suggested_action": "Тренировка с фокусом на точность, не скорость"
            })
        
        # Проверка тренда
        trend = stats.get("accuracy_trend", {})
        if trend.get("direction") == "down" and abs(trend.get("change", 0)) > 10:
            recommendations.append({
                "priority": "warning",
                "type": "fatigue",
                "message": f"Точность падает ({trend['change']}% за последние 20 раундов). Возможно усталость.",
                "suggested_action": "Рекомендуется перерыв или более лёгкие задания"
            })
        elif trend.get("direction") == "up" and trend.get("change", 0) > 10:
            recommendations.append({
                "priority": "good",
                "type": "progress",
                "message": f"Отличный прогресс! Точность выросла на {trend['change']}% за последние 20 раундов."
            })
        
        # Проверка серии ошибок
        if stats.get("current_error_streak", 0) > 5:
            recommendations.append({
                "priority": "critical",
                "type": "error_streak",
                "message": f"Серия из {stats['current_error_streak']} ошибок подряд. Рекомендуется повторить правила.",
                "suggested_action": "Повторить раздел правил + тренировочный тест"
            })
        
        # Сортировка по приоритету
        priority_order = {"critical": 0, "warning": 1, "good": 2}
        recommendations.sort(key=lambda x: priority_order.get(x["priority"], 99))
        
        return recommendations
    
    def generate_group_recommendations(self, room_code: str) -> dict:
        """Сгенерировать рекомендации по всей группе."""
        analytics = self._get_group_analytics(room_code)
        
        # Найти самые проблемные категории
        top_errors = analytics.get("top_errors", [])
        
        group_recommendations = []
        
        if top_errors:
            most_common = top_errors[0]
            group_recommendations.append({
                "priority": "warning",
                "type": "group_focus",
                "category": most_common["type"],
                "message": f"40% всех ошибок группы — «{most_common['type']}». Рекомендуется провести повторный разбор правил.",
                "suggested_action": f"Живая сессия с фокусом на «{most_common['type']}»"
            })
        
        # Найти отстающих дилеров
        low_performers = self._get_low_performers(room_code, threshold=70, min_rounds=20)
        if low_performers:
            names = ", ".join([d["display_name"] for d in low_performers[:3]])
            group_recommendations.append({
                "priority": "warning",
                "type": "low_performers",
                "message": f"Дилеры с точностью < 70%: {names}. Рекомендуется индивидуальная работа.",
                "dealers": low_performers
            })
        
        # Найти прогрессирующих
        improving = self._get_improving_dealers(room_code)
        if improving:
            names = ", ".join([d["display_name"] for d in improving[:3]])
            group_recommendations.append({
                "priority": "good",
                "type": "improving",
                "message": f"Дилеры с лучшим прогрессом: {names}. Поощрить!"
            })
        
        return {
            "recommendations": group_recommendations,
            "summary": analytics["summary"]
        }
```

---

## 6. UI отображения аналитики

### 6.1 Графики и визуализация (веб-дашборд)

Используем **Chart.js** или **Recharts** (React) / **ApexCharts** (Vue):

**Типы графиков:**

| График | Для чего | Пример |
|--------|----------|--------|
| Линейный | Динамика точности по времени | Точность дилера за 30 дней |
| Столбчатый | Сравнение категорий | Ошибки по категориям |
| Круговой | Доля ошибок | % каждой категории от общего числа |
| Тепловая карта | Активность по дням/часам | Когда дилеры тренируются больше |
| Radar/Spider | Профиль навыков дилера | Сильные/слабые стороны |

### 6.2 Radar chart — профиль навыков дилера

```
                    3-я карта Игрока
                         100%
                           │
                           │
    Выплата Пары ──────────┼────────── 3-я карта Банкира
        88%                │               71%
                           │
                           │
     Выбор победителя ─────┼─────── Выплата Банкир
          96%              │             90%
                           │
                           │
                    Выплата Ничья
                         47%

✅ Зелёная зона: 85-100%
⚠️ Жёлтая зона: 60-84%
🔴 Красная зона: < 60%
```

---

## 7. API-эндпоинты аналитики

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/rooms/{code}/analytics` | Сводная аналитика группы |
| GET | `/api/rooms/{code}/analytics/comparison` | Сравнение дилеров |
| GET | `/api/rooms/{code}/analytics/trend` | Динамика группы по дням |
| GET | `/api/rooms/{code}/analytics/recommendations` | Автоматические рекомендации по группе |
| GET | `/api/rooms/{code}/reports/dealer/{id}/pdf` | PDF-отчёт по дилеру |
| GET | `/api/rooms/{code}/reports/all/csv` | CSV всех результатов |
| GET | `/api/dealers/{id}/analytics` | Детальная аналитика по дилеру |
| GET | `/api/dealers/{id}/analytics/radar` | Данные для radar chart |
| GET | `/api/dealers/{id}/recommendations` | Рекомендации для дилера |

**Итого: 9 эндпоинтов**

---

## 8. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Алгоритм расчёта сводной аналитики | ✅ Завершено |
| 2 | Структура PDF-отчёта (шаблон, секции, данные) | ✅ Завершено |
| 3 | Структура CSV-файла (колонки, форматирование) | ✅ Завершено |
| 4 | Алгоритм автоматических рекомендаций (правила, веса, порог) | ✅ Завершено |
| 5 | UI отображения аналитики (графики, таблицы, фильтры) | ✅ Завершено |
| 6 | Radar chart — профиль навыков дилера | ✅ Завершено |
| 7 | API-эндпоинты аналитики | ✅ Завершено (9 эндпоинтов) |

**Раздел 12: Аналитика и отчёты — детализация завершена полностью (7/7 пунктов).**

---

> **Этот документ — финальная детализация раздела 12.1 "Аналитика и отчёты".**  
> **Следующий шаг:** Приступить к детализации раздела 13 "Безопасность".
