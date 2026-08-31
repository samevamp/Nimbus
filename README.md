# Nimbus

Нативное меню-бар приложение для macOS. Обход DPI из строки меню: Control Center HUD, стратегии, автообновление.

macOS 14+, universal (Apple Silicon и Intel).

Nimbus сделан **на основе** [Flowseal/zapret-mac-discord-youtube](https://github.com/Flowseal/zapret-mac-discord-youtube). Движок — [bol-van/zapret](https://github.com/bol-van/zapret) (`nfqws` через `utun` и BPF). Мы держим тот же рабочий пайплайн и пересобираем оболочку: свой UI, свои релизы, своё автообновление.

## Что умеет

- Облако в меню-баре, HUD в духе Control Center
- Запуск и остановка сервиса без отдельного окна
- Стратегии из сборки Flowseal (GameFilter вырезан)
- Пресеты IPSet: нет / стандартный / все
- Тест стратегий и пользовательские списки
- Автозапуск приложения при входе
- Автообновление с [релизов этого репозитория](https://github.com/samevamp/Nimbus/releases)

Выход закрывает только приложение в строке меню. Сервис продолжает работать, пока не нажмёте **Остановить**.

## Установка

1. Выключите VPN с туннелированием.
2. Поставьте DNS не от провайдера — Google (`8.8.8.8`) или Cloudflare (`1.1.1.1`). Ещё лучше DNS over HTTPS, например [профиль Google Public DNS](https://github.com/paulmillr/encrypted-dns).
3. Скачайте `Nimbus-macOS-universal.zip` из [Releases](https://github.com/samevamp/Nimbus/releases).
4. Откройте приложение. Если Gatekeeper ругается: ПКМ → **Открыть**, либо **Системные настройки → Конфиденциальность и безопасность → Подтвердить вход**.
5. Клик по облаку → стратегия → **Запустить**.

## Списки

При первом запуске создаётся `~/Library/Application Support/ZapretMac/lists`.

- Свои домены: `list-general-user.txt` (поддомены подхватываются сами)
- Исключения доменов: `list-exclude-user.txt`
- Исключения IP: `ipset-exclude-user.txt`

Пресет:

- **Нет** — без дополнительного обхода по IP
- **Стандартный** — `ipset-all.txt`
- **Все** — IP-профили на весь IPv4, кроме исключений

После правки списка заново выберите стратегию или пресет, чтобы перезапустить сервис.

## Сборка

```bash
./macos/build.sh
```

Архив: `dist/Nimbus-macOS-universal.zip`.

GitHub Actions (`.github/workflows/macos.yml`) собирает тот же universal-билд на каждый пуш. Релиз собирается workflow `release.yml` по тегу.

## Принудительная остановка

```bash
sudo "/Library/Application Support/ZapretMac/stop.sh"
```

## Лицензия

MIT. Copyright bol-van, Flowseal, Nimbus.
