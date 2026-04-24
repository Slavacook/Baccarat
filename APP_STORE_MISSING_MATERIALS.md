# Missing Release Materials

Короткий список того, чего ещё не хватает для публикации в App Store.

## Уже есть

- Базовая иконка проекта: `icon.svg`
- Web/PWA иконки:
  - `icons/icon_144x144.png`
  - `icons/icon_180x180.png`
  - `icons/icon_512x512.png`
- Черновик store-текстов: `APP_STORE_TEXTS_DRAFT.md`

## Не хватает точно

### Иконки для iOS/App Store

Сейчас в `export_presets.cfg` пустые iOS/App Store иконки:
- `icons/icon_1024x1024`
- `icons/iphone_120x120`
- `icons/ipad_167x167`
- `icons/app_store_1024x1024`

Что нужно добрать:
- App Store иконка 1024x1024
- iPhone/iPad иконки под экспортный пресет

Важно:
- текущих `144x144`, `180x180`, `512x512` недостаточно для полного iOS/App Store набора.

### Скриншоты для App Store Connect

В проекте не найдено готовых файлов скриншотов или preview-материалов для стора.

Что нужно добрать:
- скриншоты iPhone
- скриншоты iPad
- при желании preview video

### Privacy Policy URL

В репозитории не найдено готовой privacy policy страницы или файла.

Что нужно добрать:
- публичный URL privacy policy

### Support URL

В репозитории не найдено готовой support/contact страницы или файла.

Что нужно добрать:
- публичный support URL
- контакт для поддержки

## Есть частично, но не доведено

### Домен / сайт

В проекте есть следы домена `baccarat-trainer.ru` в deployment-конфигах, но не найдены готовые страницы:
- `/privacy`
- `/support`
- отдельная App Store landing/support page

Это можно использовать как базу, но страницы ещё нужно подготовить.

### Метаданные публикации

Черновик текстов уже подготовлен в `APP_STORE_TEXTS_DRAFT.md`, но перед публикацией всё ещё нужно руками заполнить:
- возрастной рейтинг
- support contact
- privacy details в App Store Connect
- финальное имя/подзаголовок, если захочется подправить маркетингово

## Что я бы добирал в первую очередь

1. App Store иконка 1024x1024
2. Скриншоты iPhone/iPad
3. Privacy Policy URL
4. Support URL
5. Возрастной рейтинг и privacy details в App Store Connect

