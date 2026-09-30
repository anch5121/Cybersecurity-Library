#!/usr/bin/env python3
# DO NOT CHANGE THIS FILE.
import random
import string
import argparse

import oracle, crypto
import student


# If you want to try out other messages, do it separately.
# This is the message you must inject your username into.
MESSAGE = b"Hello student of cryptography! Have fun :)"


parser = argparse.ArgumentParser(description="Grades the length extension attack on SHA1.")
parser.add_argument("username", help="your GT username (e.g. djoyner3)")
args = parser.parse_args()
injection = args.username.encode("ascii")

# Create a random 64-byte secret of letters.
print("Generating random secret... ", end="")
with open("secret.txt", "wb") as f:
    secret = "".join([
        random.choice(string.ascii_letters)
        for _ in range(64)
    ])

    f.write(secret.encode("ascii"))
print("done.")

print("=============== Student Output ===============")
message, tag = student.main(MESSAGE, injection)
print("===================== END ====================")
print()

if not isinstance(message, bytes) or not isinstance(tag, str):
    print("TEST FAILED")
    print("Something is up with your return values!")
    print(f"Should be ({type(b'')}, {type('')}), got ({type(message)}, {type(tag)})")

elif oracle.check(message, tag):
    print("TEST PASSED")
    print("Good job!")

    if injection in message and MESSAGE in message:
        print("Unless you did something really shady (like hardcode a secret, "
              "modify the oracle, etc.), you've successfully executed a length "
              "extension attack against SHA1!")
    else:
        print("However, it looks like you successfully forged a message, but didn't "
              "include your GT username or the original message in your forgery.")

else:
    print("TEST FAILED")
    print("Unfortunately, the (message, tag) pair you returned doesn't pass "
          "the oracle's integrity check. Try again!")
