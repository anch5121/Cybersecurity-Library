""" A simulated UF-CMA integrity oracle.

It simply tells you whether or not a message has integrity based on the scheme
outlined in the instructions:

    expected_tag = SHA1(secret || message)

DO NOT CHANGE THIS FILE. We will replace it (as well as the secret) with a fresh
copy when grading, and your solution MUST still work.
"""
import typing
import crypto


# A hacky way of tracking what messages the oracle has seen.
# Don't try to be cheeky: resetting this list won't do you any good in the
# autograder since the secret changes, anyway.
_SEEN: typing.List[bytes] = []

def query(message: bytes) -> str:
    """ Simulates sending a message to an oracle.

    NOTE: Despite the fact that you know the secret hidden within `secret.txt`
    and could obviously break integrity this way, we will use different secrets
    in the autograder.

    It's included here for simplicity, and so that you can see the "guts" of the
    oracle.

    The only REAL knowledge you have about the secret is that it's 64 bytes
    long. Again, YOUR EXPLOIT SHOULD NOT RELY ON THE VALUE OF SECRET.TXT.
    """
    sha1 = crypto.Sha1()
    with open("secret.txt", "rb") as secret_file:
        sha1.update(secret_file.read())

    if not isinstance(message, (bytes, bytearray)):
        raise ValueError(f"expected bytes for message, got {type(message)}")

    _SEEN.append(message)
    sha1.update(message)
    tag = sha1.hexdigest()

    print("Message:", repr(message))
    print("Tag:    ", tag)
    return tag

def verify(message: bytes, tag: str) -> bool:
    """ Simulates the verification oracle in UF-CMA.
    """
    valid = query(message) == tag
    _SEEN.pop(-1)   # our query
    return valid

def check(message: bytes, tag: str) -> bool:
    """ Simulates an adversary returning a (message, tag) pair in UF-CMA.

    The tag should be valid for the message WITHOUT having queried the message
    to the oracle. If you just need verification, see `verify()`.

    If you get this function to return `True`, you probably have a solution.
    """
    if not isinstance(message, bytes) or not isinstance(tag, str):
        print(f"Invalid parameters: expected bytes, str; got {type(message)} and {type(tag)}")
        return False

    if message in _SEEN:
        print("This message has already been seen by the oracle!")
        return False

    expectations, reality = query(message), tag
    print(f"Expected tag:", expectations)
    print(f"Actual tag:  ", reality)
    _SEEN.pop(-1)   # our query

    if expectations == reality:
        print("Integrity check passed!")
        return True

    print("Integrity check failed.")
    return False
