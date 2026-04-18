#!/usr/bin/env python3
import argparse
import imaplib
import os
import smtplib
import ssl
import sys
from datetime import datetime
from email.message import EmailMessage


def load_env_file(path: str) -> dict[str, str]:
    env: dict[str, str] = {}
    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip("'").strip('"')
    return env


def require(config: dict[str, str], key: str) -> str:
    value = config.get(key, "")
    if not value:
        raise ValueError(f"Missing required config: {key}")
    return value


def encode_imap_utf7(value: str) -> str:
    return value.encode("utf-7").decode("ascii").replace("/", ",")


def send_message(config: dict[str, str], attachment_path: str) -> None:
    smtp_host = require(config, "SMTP_HOST")
    smtp_port = int(config.get("SMTP_PORT", "465"))
    smtp_username = require(config, "SMTP_USERNAME")
    smtp_password = require(config, "SMTP_PASSWORD")
    smtp_from = require(config, "SMTP_FROM")
    smtp_to = require(config, "SMTP_TO")
    smtp_ssl = config.get("SMTP_SSL", "1") == "1"
    smtp_starttls = config.get("SMTP_STARTTLS", "0") == "1"
    host_tag = config.get("HOST_TAG", os.uname().nodename)

    subject = f"[OneCloud] Vaultwarden DB backup {host_tag} {datetime.now():%Y-%m-%d %H:%M}"
    body = "\n".join(
        [
            "Vaultwarden backup completed.",
            f"Host: {host_tag}",
            f"Time: {datetime.now():%Y-%m-%d %H:%M:%S}",
            f"Attachment: {os.path.basename(attachment_path)}",
        ]
    )

    message = EmailMessage()
    message["From"] = smtp_from
    message["To"] = smtp_to
    message["Subject"] = subject
    message.set_content(body)

    with open(attachment_path, "rb") as handle:
        data = handle.read()
    message.add_attachment(
        data,
        maintype="application",
        subtype="gzip",
        filename=os.path.basename(attachment_path),
    )

    if smtp_ssl:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(smtp_host, smtp_port, context=context, timeout=30) as server:
            server.login(smtp_username, smtp_password)
            server.send_message(message)
        return

    with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as server:
        server.ehlo()
        if smtp_starttls:
            server.starttls(context=ssl.create_default_context())
            server.ehlo()
        server.login(smtp_username, smtp_password)
        server.send_message(message)


def send_custom_message(
    config: dict[str, str],
    subject: str,
    body: str,
    attachment_path: str | None = None,
) -> None:
    smtp_host = require(config, "SMTP_HOST")
    smtp_port = int(config.get("SMTP_PORT", "465"))
    smtp_username = require(config, "SMTP_USERNAME")
    smtp_password = require(config, "SMTP_PASSWORD")
    smtp_from = require(config, "SMTP_FROM")
    smtp_to = require(config, "SMTP_TO")
    smtp_ssl = config.get("SMTP_SSL", "1") == "1"
    smtp_starttls = config.get("SMTP_STARTTLS", "0") == "1"

    message = EmailMessage()
    message["From"] = smtp_from
    message["To"] = smtp_to
    message["Subject"] = subject
    message.set_content(body)

    if attachment_path:
        with open(attachment_path, "rb") as handle:
            data = handle.read()
        message.add_attachment(
            data,
            maintype="application",
            subtype="gzip",
            filename=os.path.basename(attachment_path),
        )

    if smtp_ssl:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(smtp_host, smtp_port, context=context, timeout=30) as server:
            server.login(smtp_username, smtp_password)
            server.send_message(message)
        return

    with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as server:
        server.ehlo()
        if smtp_starttls:
            server.starttls(context=ssl.create_default_context())
            server.ehlo()
        server.login(smtp_username, smtp_password)
        server.send_message(message)


def cleanup_sent_folder(config: dict[str, str]) -> None:
    if config.get("IMAP_CLEAN_SENT", "0") != "1":
        return

    mail = None
    try:
        imap_host = require(config, "IMAP_HOST")
        imap_port = int(config.get("IMAP_PORT", "993"))
        imap_username = require(config, "IMAP_USERNAME")
        imap_password = require(config, "IMAP_PASSWORD")
        candidates = [
            item.strip()
            for item in config.get("IMAP_SENT_FOLDERS", "Sent Messages,已发送,&XfJT0ZAB-").split(",")
            if item.strip()
        ]

        mail = imaplib.IMAP4_SSL(imap_host, imap_port)
        mail.login(imap_username, imap_password)
        selected = None
        for folder in candidates:
            status, _ = mail.select(encode_imap_utf7(folder))
            if status == "OK":
                selected = folder
                break
        if not selected:
            raise RuntimeError("sent folder not found")

        status, data = mail.search(None, "ALL")
        if status == "OK" and data and data[0]:
            mail.store("1:*", "+FLAGS", "\\Deleted")
            mail.expunge()
        mail.close()
    except Exception as exc:
        print(f"Warning: sent-folder cleanup skipped: {exc}", file=sys.stderr)
    finally:
        try:
            if mail is not None:
                mail.logout()
        except Exception:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Send OneCloud backup email")
    parser.add_argument("--config", required=True, help="Path to backup env file")
    parser.add_argument("--attachment", help="Backup archive path")
    parser.add_argument("--subject", help="Custom mail subject")
    parser.add_argument("--body", help="Custom mail body")
    args = parser.parse_args()

    if not os.path.isfile(args.config):
        print(f"Config not found: {args.config}", file=sys.stderr)
        return 1
    if args.attachment and not os.path.isfile(args.attachment):
        print(f"Attachment not found: {args.attachment}", file=sys.stderr)
        return 1

    config = load_env_file(args.config)
    try:
        if args.subject or args.body:
            send_custom_message(
                config,
                args.subject or "[OneCloud] Backup notification",
                args.body or "Backup notification",
                args.attachment,
            )
        else:
            if not args.attachment:
                print("--attachment is required unless --subject/--body is used", file=sys.stderr)
                return 1
            send_message(config, args.attachment)
            cleanup_sent_folder(config)
    except Exception as exc:
        print(f"Failed to send backup email: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
