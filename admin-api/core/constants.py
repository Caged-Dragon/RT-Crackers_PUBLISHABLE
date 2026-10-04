"""Domain constants. The database stores single-character codes; the API exposes both code and label."""
from __future__ import annotations

from datetime import time

IST_OFFSET_MINUTES = 330

# ---------------------------------------------------------------- users
USER_ACTIVE = "A"
USER_STATUS_LABELS = {"A": "active", "I": "inactive", "S": "suspended", "B": "blocked", "D": "deleted"}
CUSTOMER_ROLE_CODE = "CUSTOMER"
GENDERS = {"M": "male", "F": "female", "O": "other"}

# ------------------------------------------------------------- products
PRODUCT_ACTIVE = "A"
PRODUCT_STATUS_LABELS = {"D": "draft", "A": "active", "I": "inactive", "X": "archived"}

# --------------------------------------------------------------- orders
ORDER_PLACED, ORDER_CONFIRMED, ORDER_PACKED = "P", "C", "K"
ORDER_SHIPPED, ORDER_OUT_FOR_DELIVERY, ORDER_DELIVERED = "S", "O", "D"
ORDER_CANCELLED, ORDER_RETURNED = "X", "R"
ORDER_STATUS_LABELS = {
    "P": "placed", "C": "confirmed", "K": "packed", "S": "shipped",
    "O": "out_for_delivery", "D": "delivered", "X": "cancelled", "R": "returned",
}
ORDER_STATUS_DISPLAY = {
    "P": "Order Placed", "C": "Order Confirmed", "K": "Packed", "S": "Shipped",
    "O": "Out for Delivery", "D": "Delivered", "X": "Cancelled", "R": "Returned",
}
ORDER_FLOW = ["P", "C", "K", "S", "O", "D"]
CANCELLABLE_STATUSES = {"P", "C"}
PAYMENT_STATUS_LABELS = {"P": "pending", "C": "collected", "F": "failed", "R": "refunded", "Q": "partially_refunded"}
COD_METHOD_CODE = "COD"

# ---------------------------------------------------------------- carts
CART_ACTIVE, CART_CONVERTED, CART_ABANDONED = "A", "C", "X"
MAX_CART_LINE_QTY = 1000
MAX_GUEST_CART_LINES = 50
CART_TOKEN_HEADER = "X-Cart-Token"

# -------------------------------------------------------------- coupons
COUPON_PERCENT, COUPON_FLAT = "P", "F"
PERSONAL_COUPON_PREFIX = "RFR"  # coupons minted for referral rewards (never listed publicly)
COUPON_USAGE_APPLIED, COUPON_USAGE_REVERSED = "A", "R"

# -------------------------------------------------------------- reviews
REVIEW_PENDING, REVIEW_APPROVED, REVIEW_REJECTED, REVIEW_HIDDEN = "P", "A", "R", "H"
REVIEW_STATUS_LABELS = {"P": "pending", "A": "approved", "R": "rejected", "H": "hidden"}
REVIEW_REPORT_REASONS = {"S": "spam", "A": "abusive", "F": "fake", "I": "irrelevant", "O": "other"}
MAX_REVIEW_IMAGES = 5

# ------------------------------------------------------------ referrals
REWARD_PENDING, REWARD_GRANTED, REWARD_EXPIRED = "P", "G", "X"
REWARD_STATUS_LABELS = {"P": "pending", "G": "granted", "X": "expired"}
REWARD_ROLE_REFERRER, REWARD_ROLE_REFEREE = "R", "E"

# -------------------------------------------------------- notifications
NOTIF_ORDER, NOTIF_PROMOTION, NOTIF_SYSTEM, NOTIF_FESTIVAL = "O", "P", "S", "F"
NOTIFICATION_TYPE_LABELS = {"O": "order", "P": "promotion", "S": "system", "F": "festival"}
MARKETING_NOTIFICATION_TYPES = {"P", "F"}  # honour opt-out; transactional (O, S) always sent
CHANNEL_IN_APP, CHANNEL_EMAIL, CHANNEL_SMS, CHANNEL_WHATSAPP = "A", "E", "S", "W"
DELIVERY_QUEUED, DELIVERY_SENT, DELIVERY_FAILED = "Q", "S", "F"

# ----------------------------------------------------------------- misc
ADDRESS_TYPE_LABELS = {"H": "home", "W": "work", "O": "other"}
RECENTLY_VIEWED_CAP = 50
DEFAULT_WISHLIST_NAME = "My Wishlist"
DEFAULT_ORDER_CUTOFF = time(16, 0)
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}

# ---------------------------------------------------- setting keys (DB `settings` table)
SETTING_COD_ENABLED = "cod_enabled"
SETTING_MIN_ORDER_AMOUNT = "min_order_amount"
SETTING_REFERRER_REWARD = "referral_referrer_reward"
SETTING_REFEREE_REWARD = "referral_referee_reward"
FLAG_WISHLIST = "wishlist"
FLAG_REFERRAL = "referral_program"
