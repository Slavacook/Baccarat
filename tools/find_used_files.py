#!/usr/bin/env python3
"""
Статический анализатор зависимостей для Godot проекта
Находит ВСЕ используемые файлы начиная с main сцены и autoload скриптов
"""

import os
import re
from pathlib import Path
from typing import Set, List

# Путь к корню проекта
PROJECT_ROOT = Path(__file__).parent.parent

class GodotDependencyAnalyzer:
    def __init__(self):
        self.used_files: Set[str] = set()
        self.queue: List[str] = []
        self.uid_to_path: dict[str, str] = {}  # UID → path mapping

    def analyze(self) -> Set[str]:
        """Главный метод анализа"""
        print("🔍 Начинаем анализ зависимостей Godot проекта...\n")

        # 0. Строим UID → path mapping
        print("🗺️  Построение UID → path mapping...")
        self._build_uid_mapping()
        print(f"   Найдено {len(self.uid_to_path)} UID маппингов\n")

        # 1. Парсим project.godot для autoload и main сцены
        self._parse_project_godot()

        # 2. Обрабатываем очередь файлов
        while self.queue:
            file_path_or_uid = self.queue.pop(0)

            # Резолвим UID если нужно
            file_path = self._resolve_path(file_path_or_uid)

            if file_path in self.used_files:
                continue

            self.used_files.add(file_path)
            if file_path != file_path_or_uid:
                print(f"  ✓ {file_path} (was {file_path_or_uid})")
            else:
                print(f"  ✓ {file_path}")

            # Анализируем файл в зависимости от типа
            if file_path.endswith('.tscn'):
                self._parse_scene_file(file_path)
            elif file_path.endswith('.gd'):
                self._parse_script_file(file_path)
            elif file_path.endswith('.tres') or file_path.endswith('.res'):
                self._parse_resource_file(file_path)

        return self.used_files

    def _build_uid_mapping(self):
        """Построить маппинг UID → path из всех .tscn и .import файлов"""
        for root, dirs, files in os.walk(PROJECT_ROOT):
            # Пропускаем системные папки
            dirs[:] = [d for d in dirs if d not in ['.git', 'tools', '__pycache__']]

            for file in files:
                if file.endswith('.tscn'):
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, PROJECT_ROOT)
                    godot_path = "res://" + rel_path.replace(os.sep, '/')

                    # Читаем первую строку .tscn для поиска UID
                    try:
                        with open(full_path, 'r', encoding='utf-8') as f:
                            first_line = f.readline()
                            match = re.search(r'uid="(uid://[^"]+)"', first_line)
                            if match:
                                uid = match.group(1)
                                self.uid_to_path[uid] = godot_path
                    except Exception as e:
                        pass

                elif file.endswith('.import'):
                    full_path = os.path.join(root, file)
                    try:
                        with open(full_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            # Ищем uid и path в .import файле
                            uid_match = re.search(r'uid="(uid://[^"]+)"', content)
                            path_match = re.search(r'path="(res://[^"]+)"', content)
                            if uid_match and path_match:
                                uid = uid_match.group(1)
                                path = path_match.group(1)
                                # Для .import файлов нужен путь к оригинальному файлу
                                original_path = "res://" + os.path.relpath(full_path.replace('.import', ''), PROJECT_ROOT).replace(os.sep, '/')
                                self.uid_to_path[uid] = original_path
                    except Exception as e:
                        pass

    def _resolve_path(self, path_or_uid: str) -> str:
        """Резолвинг пути (может быть res://... или uid://...)"""
        if path_or_uid.startswith("uid://"):
            # Пытаемся найти в маппинге
            resolved = self.uid_to_path.get(path_or_uid)
            if resolved:
                return resolved
            else:
                # UID не найден - возвращаем как есть
                return path_or_uid
        elif path_or_uid.startswith("*res://"):
            # Убираем * префикс для autoload
            return path_or_uid[1:]
        else:
            return path_or_uid

    def _parse_project_godot(self):
        """Парсинг project.godot для поиска autoload и main сцены"""
        project_file = PROJECT_ROOT / "project.godot"
        if not project_file.exists():
            print("❌ project.godot не найден!")
            return

        content = project_file.read_text(encoding='utf-8')

        # 1. Main сцена
        match = re.search(r'run/main_scene="([^"]+)"', content)
        if match:
            main_scene = match.group(1)
            self.queue.append(main_scene)
            print(f"🎬 Main сцена: {main_scene}")

        # 2. Autoload скрипты
        autoload_section = False
        for line in content.splitlines():
            if line.strip() == "[autoload]":
                autoload_section = True
                continue

            if autoload_section:
                if line.strip().startswith("["):
                    break  # Вышли из секции autoload

                match = re.search(r'"([^"]*res://[^"]+)"', line)
                if match:
                    autoload_path = match.group(1)
                    self.queue.append(autoload_path)
                    print(f"⚡ Autoload: {autoload_path}")

    def _parse_scene_file(self, scene_path: str):
        """Парсинг .tscn файла для поиска зависимостей"""
        full_path = PROJECT_ROOT / scene_path.replace("res://", "")
        if not full_path.exists():
            return

        content = full_path.read_text(encoding='utf-8')

        # 1. Скрипты через [ext_resource]
        for match in re.finditer(r'\[ext_resource[^\]]*path="([^"]+\.gd)"', content):
            script_path = match.group(1)
            if script_path not in self.used_files:
                self.queue.append(script_path)

        # 2. Подсцены через [ext_resource]
        for match in re.finditer(r'\[ext_resource[^\]]*path="([^"]+\.tscn)"', content):
            subscene_path = match.group(1)
            if subscene_path not in self.used_files:
                self.queue.append(subscene_path)

        # 3. Ресурсы (.tres, .res)
        for match in re.finditer(r'\[ext_resource[^\]]*path="([^"]+\.(?:tres|res))"', content):
            resource_path = match.group(1)
            if resource_path not in self.used_files:
                self.queue.append(resource_path)

        # 4. Текстуры и другие ассеты
        for match in re.finditer(r'\[ext_resource[^\]]*path="([^"]+\.(?:png|jpg|svg|ogg|wav|mp3))"', content):
            asset_path = match.group(1)
            if asset_path not in self.used_files:
                self.queue.append(asset_path)

    def _parse_script_file(self, script_path: str):
        """Парсинг .gd файла для поиска load/preload"""
        full_path = PROJECT_ROOT / script_path.replace("res://", "")
        if not full_path.exists():
            return

        content = full_path.read_text(encoding='utf-8')

        # 1. preload("res://...")
        for match in re.finditer(r'preload\("(res://[^"]+)"\)', content):
            loaded_path = match.group(1)
            if loaded_path not in self.used_files:
                self.queue.append(loaded_path)

        # 2. load("res://...")
        for match in re.finditer(r'load\("(res://[^"]+)"\)', content):
            loaded_path = match.group(1)
            if loaded_path not in self.used_files:
                self.queue.append(loaded_path)

        # 3. extends ClassName (нужно найти файл класса)
        # Примечание: это сложнее, т.к. требует поиска class_name
        # Пока пропускаем, т.к. большинство зависимостей через load/preload

    def _parse_resource_file(self, resource_path: str):
        """Парсинг .tres/.res файла"""
        full_path = PROJECT_ROOT / resource_path.replace("res://", "")
        if not full_path.exists():
            return

        content = full_path.read_text(encoding='utf-8')

        # Ищем пути к другим ресурсам
        for match in re.finditer(r'Resource\("(res://[^"]+)"\)', content):
            dep_path = match.group(1)
            if dep_path not in self.used_files:
                self.queue.append(dep_path)

    def generate_report(self, used_files: Set[str]):
        """Генерация отчёта с группировкой по типам"""
        print("\n" + "="*80)
        print("📊 ОТЧЁТ ОБ ИСПОЛЬЗУЕМЫХ ФАЙЛАХ")
        print("="*80 + "\n")

        # Группировка по типам
        scripts = [f for f in used_files if f.endswith('.gd')]
        scenes = [f for f in used_files if f.endswith('.tscn')]
        resources = [f for f in used_files if f.endswith(('.tres', '.res'))]
        assets = [f for f in used_files if f.endswith(('.png', '.jpg', '.svg', '.ogg', '.wav', '.mp3'))]

        print(f"📝 Скрипты (.gd): {len(scripts)}")
        for s in sorted(scripts):
            print(f"  • {s}")

        print(f"\n🎬 Сцены (.tscn): {len(scenes)}")
        for s in sorted(scenes):
            print(f"  • {s}")

        print(f"\n📦 Ресурсы (.tres/.res): {len(resources)}")
        for r in sorted(resources):
            print(f"  • {r}")

        print(f"\n🖼️  Ассеты (PNG/OGG/etc): {len(assets)}")
        for a in sorted(assets):
            print(f"  • {a}")

        print(f"\n📊 ИТОГО используемых файлов: {len(used_files)}")

    def find_orphans(self, used_files: Set[str]):
        """Найти неиспользуемые файлы"""
        print("\n" + "="*80)
        print("🗑️  ПОТЕНЦИАЛЬНО НЕИСПОЛЬЗУЕМЫЕ ФАЙЛЫ")
        print("="*80 + "\n")

        # Сканируем все файлы в проекте
        all_files = set()
        for root, dirs, files in os.walk(PROJECT_ROOT):
            # Пропускаем системные папки
            dirs[:] = [d for d in dirs if d not in ['.godot', '.git', '.import', 'tools', '__pycache__']]

            for file in files:
                if file.endswith(('.gd', '.tscn', '.tres', '.res', '.png', '.jpg', '.svg', '.ogg', '.wav', '.mp3')):
                    rel_path = os.path.relpath(os.path.join(root, file), PROJECT_ROOT)
                    godot_path = "res://" + rel_path.replace(os.sep, '/')
                    all_files.add(godot_path)

        orphans = all_files - used_files

        if orphans:
            # Группировка по типам
            orphan_scripts = [f for f in orphans if f.endswith('.gd')]
            orphan_scenes = [f for f in orphans if f.endswith('.tscn')]
            orphan_resources = [f for f in orphans if f.endswith(('.tres', '.res'))]
            orphan_assets = [f for f in orphans if f.endswith(('.png', '.jpg', '.svg', '.ogg', '.wav', '.mp3'))]

            print(f"❌ Неиспользуемые скрипты (.gd): {len(orphan_scripts)}")
            for s in sorted(orphan_scripts):
                print(f"  • {s}")

            print(f"\n❌ Неиспользуемые сцены (.tscn): {len(orphan_scenes)}")
            for s in sorted(orphan_scenes):
                print(f"  • {s}")

            print(f"\n❌ Неиспользуемые ресурсы (.tres/.res): {len(orphan_resources)}")
            for r in sorted(orphan_resources):
                print(f"  • {r}")

            print(f"\n❌ Неиспользуемые ассеты: {len(orphan_assets)}")
            for a in sorted(orphan_assets):
                print(f"  • {a}")

            print(f"\n🗑️  ИТОГО неиспользуемых файлов: {len(orphans)}")
        else:
            print("✅ Неиспользуемые файлы не найдены!")


if __name__ == "__main__":
    analyzer = GodotDependencyAnalyzer()
    used_files = analyzer.analyze()
    analyzer.generate_report(used_files)
    analyzer.find_orphans(used_files)

    print("\n" + "="*80)
    print("✅ Анализ завершён!")
    print("="*80)
