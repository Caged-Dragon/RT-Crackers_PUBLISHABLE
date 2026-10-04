from typing import Any

import psycopg

from .exceptions import (
    EmailNotFoundError,
    InvalidMailboxError,
    MailboxNotFoundError,
)


class EmailRepository:
    """All PostgreSQL access for the email module."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self.conn = conn

    def get_mailbox(self, mailbox_id: int) -> dict[str, Any]:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, name, email, is_active, created_at
                FROM mailboxes
                WHERE id = %s
                """,
                (mailbox_id,),
            )
            row = cur.fetchone()

        if not row:
            raise MailboxNotFoundError(f"Mailbox {mailbox_id} was not found.")

        if not row["is_active"]:
            raise InvalidMailboxError(f"Mailbox {mailbox_id} is inactive.")

        return row

    def get_mailbox_by_email(self, email: str) -> dict[str, Any]:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, name, email, is_active, created_at
                FROM mailboxes
                WHERE LOWER(email) = LOWER(%s)
                """,
                (email,),
            )
            row = cur.fetchone()

        if not row:
            raise MailboxNotFoundError(
                f"Mailbox {email} was not found."
            )

        if not row["is_active"]:
            raise InvalidMailboxError(f"Mailbox {email} is inactive.")

        return row

    def list_mailboxes(self) -> list[dict[str, Any]]:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, name, email, is_active, created_at
                FROM mailboxes
                WHERE is_active = TRUE
                ORDER BY name
                """
            )
            return list(cur.fetchall())

    def create_outbound_email(
        self,
        *,
        mailbox_id: int,
        from_address: str,
        to_address: str,
        cc: str | None,
        bcc: str | None,
        reply_to: str | None,
        subject: str,
        body_text: str | None,
        body_html: str | None,
        status: str,
        resend_email_id: str | None,
        thread_id: str | None,
        in_reply_to: str | None,
    ) -> int:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO emails (
                    resend_email_id, mailbox_id, from_address, to_address,
                    cc, bcc, reply_to, subject, body_text, body_html,
                    direction, status, is_read, thread_id, in_reply_to
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'outbound',
                    %s, TRUE, %s, %s
                )
                RETURNING id
                """,
                (
                    resend_email_id, mailbox_id, from_address, to_address,
                    cc, bcc, reply_to, subject, body_text, body_html,
                    status, thread_id, in_reply_to,
                ),
            )
            row = cur.fetchone()

        self.conn.commit()
        return int(row["id"])

    def create_inbound_email(
        self,
        *,
        mailbox_id: int,
        resend_email_id: str | None,
        from_address: str,
        to_address: str,
        cc: str | None,
        bcc: str | None,
        reply_to: str | None,
        subject: str,
        body_text: str | None,
        body_html: str | None,
        message_id: str | None,
        in_reply_to: str | None,
        thread_id: str | None,
        event_data: dict[str, Any],
    ) -> int:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO emails (
                    resend_email_id, mailbox_id, from_address, to_address,
                    cc, bcc, reply_to, subject, body_text, body_html,
                    direction, status, is_read, message_id, in_reply_to,
                    thread_id, resend_event_data
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'inbound',
                    'received', FALSE, %s, %s, %s, %s
                )
                RETURNING id
                """,
                (
                    resend_email_id, mailbox_id, from_address, to_address,
                    cc, bcc, reply_to, subject, body_text, body_html,
                    message_id, in_reply_to, thread_id, event_data,
                ),
            )
            row = cur.fetchone()

        self.conn.commit()
        return int(row["id"])

    def list_messages(
        self,
        *,
        mailbox_id: int,
        direction: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        query = """
            SELECT id, mailbox_id, from_address, to_address, subject,
                   direction, status, is_read, is_starred, created_at
            FROM emails
            WHERE mailbox_id = %s
              AND is_deleted = FALSE
        """
        params: list[Any] = [mailbox_id]

        if direction:
            query += " AND direction = %s"
            params.append(direction)

        query += " ORDER BY created_at DESC LIMIT %s OFFSET %s"
        params.extend([limit, offset])

        with self.conn.cursor() as cur:
            cur.execute(query, params)
            return list(cur.fetchall())

    def get_message(self, email_id: int, *, include_deleted: bool = False) -> dict[str, Any]:
        with self.conn.cursor() as cur:
            if include_deleted:
                cur.execute(
                    "SELECT * FROM emails WHERE id = %s",
                    (email_id,),
                )
            else:
                cur.execute(
                    """
                    SELECT *
                    FROM emails
                    WHERE id = %s AND is_deleted = FALSE
                    """,
                    (email_id,),
                )
            row = cur.fetchone()

        if not row:
            raise EmailNotFoundError(f"Email {email_id} was not found.")

        return row

    def set_read(self, email_id: int, value: bool) -> None:
        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE emails SET is_read = %s WHERE id = %s",
                (value, email_id),
            )
        self.conn.commit()

    def set_starred(self, email_id: int, value: bool) -> None:
        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE emails SET is_starred = %s WHERE id = %s",
                (value, email_id),
            )
        self.conn.commit()


    def list_folder_messages(
        self,
        *,
        mailbox_id: int,
        folder: str,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        query = """
            SELECT id, mailbox_id, from_address, to_address, subject,
                   direction, status, is_read, is_starred, is_archived,
                   is_deleted, created_at
            FROM emails
            WHERE mailbox_id = %s
              AND is_deleted = FALSE
              AND (
                    (%s = 'inbox' AND direction = 'inbound' AND is_archived = FALSE)
                 OR (%s = 'sent' AND direction = 'outbound')
                 OR (%s = 'starred' AND is_starred = TRUE AND is_archived = FALSE)
                 OR (%s = 'archived' AND is_archived = TRUE AND is_deleted = FALSE)
                 OR (%s = 'trash' AND is_deleted = TRUE)
                 OR (%s = 'drafts' AND direction = 'draft')
              )
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
        """
        # Trash is intentionally queried separately below because the common
        # WHERE clause above excludes it.
        if folder == "trash":
            query = """
                SELECT id, mailbox_id, from_address, to_address, subject,
                       direction, status, is_read, is_starred, is_archived,
                       is_deleted, created_at
                FROM emails
                WHERE mailbox_id = %s AND is_deleted = TRUE
                ORDER BY created_at DESC LIMIT %s OFFSET %s
            """
            with self.conn.cursor() as cur:
                cur.execute(query, (mailbox_id, limit, offset))
                return list(cur.fetchall())

        params = [mailbox_id, folder, folder, folder, folder, folder, folder, limit, offset]
        with self.conn.cursor() as cur:
            cur.execute(query, params)
            return list(cur.fetchall())

    def search_messages(
        self,
        *,
        mailbox_id: int,
        query_text: str,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        q = "%" + query_text.strip() + "%"
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, mailbox_id, from_address, to_address, subject,
                       direction, status, is_read, is_starred, is_archived,
                       is_deleted, created_at
                FROM emails
                WHERE mailbox_id = %s
                  AND (
                    from_address ILIKE %s OR to_address ILIKE %s
                    OR subject ILIKE %s OR body_text ILIKE %s
                  )
                ORDER BY created_at DESC
                LIMIT %s OFFSET %s
                """,
                (mailbox_id, q, q, q, q, limit, offset),
            )
            return list(cur.fetchall())

    def set_archived(self, email_id: int, value: bool) -> None:
        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE emails SET is_archived = %s WHERE id = %s",
                (value, email_id),
            )
        self.conn.commit()

    def set_deleted(self, email_id: int, value: bool) -> None:
        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE emails SET is_deleted = %s WHERE id = %s",
                (value, email_id),
            )
        self.conn.commit()

    def create_draft(
        self,
        *,
        mailbox_id: int,
        to_address: str | None,
        cc: str | None,
        bcc: str | None,
        subject: str,
        body_text: str | None,
        body_html: str | None,
        thread_id: str | None = None,
    ) -> int:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO emails (
                    mailbox_id, from_address, to_address, cc, bcc, subject,
                    body_text, body_html, direction, status, is_read,
                    thread_id
                )
                SELECT id, email, %s, %s, %s, %s, %s, %s, 'draft',
                       'draft', TRUE, %s
                FROM mailboxes
                WHERE id = %s AND is_active = TRUE
                RETURNING id
                """,
                (to_address, cc, bcc, subject, body_text, body_html, thread_id, mailbox_id),
            )
            row = cur.fetchone()
            if not row:
                raise MailboxNotFoundError(f"Mailbox {mailbox_id} was not found.")
        self.conn.commit()
        return int(row["id"])
