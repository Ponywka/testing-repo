#!/usr/bin/env python3

import html
import json
import os
import sys
import urllib.parse
import urllib.request


def getenv_required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        print(f"Missing required env: {name}", file=sys.stderr)
        sys.exit(1)
    return value


def send_telegram_message(bot_token: str, chat_id: str, text: str) -> None:
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"

    data = urllib.parse.urlencode({
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": "true",
    }).encode()

    request = urllib.request.Request(url, data=data, method="POST")

    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            body = response.read().decode("utf-8", errors="replace")

            if response.status < 200 or response.status >= 300:
                raise RuntimeError(f"Telegram API returned HTTP {response.status}: {body}")

    except Exception as exc:
        raise RuntimeError(f"Failed to send message to chat {chat_id}: {exc}") from exc


def build_message(event: dict) -> str:
    lines = [
        "<b>Github event</b>",
        "Commits:",
    ]

    commits = event.get("commits") or []
    for commit in commits:
        message = commit.get("message") or ""
        message_first_line = html.escape(message.splitlines()[0] if message else "No message")
        lines.append(f"- {message_first_line}")

    pusher = event.get("pusher") or {}
    pusher_name = html.escape(pusher.get("name") or "unknown")
    lines.append(f"Pushed by: {pusher_name}")

    return "\n".join(lines)


def main() -> int:
    bot_token = getenv_required("TELEGRAM_BOT_TOKEN")
    chat_ids_raw = getenv_required("TELEGRAM_CHAT_IDS")
    event_path = getenv_required("GITHUB_EVENT_PATH")

    with open(event_path, "r", encoding="utf-8") as file:
        event = json.load(file)

    text = build_message(event)

    chat_ids = [
        chat_id.strip()
        for chat_id in chat_ids_raw.split(",")
        if chat_id.strip()
    ]

    if not chat_ids:
        print("No Telegram chat IDs configured", file=sys.stderr)
        return 1

    failed = False

    for chat_id in chat_ids:
        try:
            send_telegram_message(bot_token, chat_id, text)
        except Exception as exc:
            print(exc, file=sys.stderr)
            failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
