import hashlib
from secrets import token_bytes
from Crypto.Cipher import AES


def derive_key(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 200_000)


def encrypt(plaintext: bytes, key: bytes) -> bytes:
    nonce = token_bytes(12)
    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    ct, tag = cipher.encrypt_and_digest(plaintext)
    return nonce + tag + ct
