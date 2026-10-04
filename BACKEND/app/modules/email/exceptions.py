class EmailBackendError(Exception):
    """Base exception for the email backend."""


class MailboxNotFoundError(EmailBackendError):
    """Requested mailbox does not exist."""


class EmailNotFoundError(EmailBackendError):
    """Requested email does not exist."""


class InvalidMailboxError(EmailBackendError):
    """Requested mailbox is invalid or inactive."""


class EmailProviderError(EmailBackendError):
    """The email provider rejected or failed an operation."""
