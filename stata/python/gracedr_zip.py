from __future__ import annotations

import importlib
import os
import sys
import zipfile
from dataclasses import dataclass

PASSPHRASE_VARIABLE = "GRACEDR_PASSPHRASE"
MEMBER_NAME = "data.dta"


class PassphraseUnavailable(Exception):
    pass


@dataclass(frozen=True)
class Failure:
    code: int
    lines: tuple[str, ...]


def read_passphrase(confirm: bool) -> bytes:
    value = os.environ.get(PASSPHRASE_VARIABLE, "")
    if value:
        return value.encode("utf-8")
    return prompt_passphrase(confirm)


def prompt_passphrase(confirm: bool) -> bytes:
    try:
        import tkinter
        from tkinter import simpledialog
    except ImportError as error:
        raise PassphraseUnavailable from error
    try:
        root = tkinter.Tk()
    except tkinter.TclError as error:
        raise PassphraseUnavailable from error
    try:
        root.withdraw()
        root.attributes("-topmost", True)
        first = simpledialog.askstring("gracedr", "Password:", show="*", parent=root)
        if not first:
            raise PassphraseUnavailable
        if confirm:
            second = simpledialog.askstring("gracedr", "Repeat password:", show="*", parent=root)
            if second != first:
                raise PassphraseUnavailable
    finally:
        root.destroy()
    return first.encode("utf-8")


def save_archive(plain_path: str, archive_path: str, passphrase: bytes) -> None:
    import pyzipper

    partial_path = archive_path + ".tmp"
    try:
        with pyzipper.AESZipFile(
            partial_path,
            "w",
            compression=pyzipper.ZIP_DEFLATED,
            encryption=pyzipper.WZ_AES,
        ) as archive:
            archive.setpassword(passphrase)
            archive.setencryption(pyzipper.WZ_AES, nbits=256)
            archive.write(plain_path, MEMBER_NAME)
        os.replace(partial_path, archive_path)
    finally:
        if os.path.exists(partial_path):
            os.remove(partial_path)


def load_archive(archive_path: str, plain_path: str, passphrase: bytes) -> None:
    import pyzipper

    with pyzipper.AESZipFile(archive_path) as archive:
        member = archive.getinfo(MEMBER_NAME)
        if not member.flag_bits & 1:
            raise zipfile.BadZipFile("member is not encrypted")
        archive.setpassword(passphrase)
        content = archive.read(MEMBER_NAME)
    with open(plain_path, "wb") as handle:
        handle.write(content)


def failure_for(command: str, error: BaseException, archive_path: str) -> Failure:
    if isinstance(error, ImportError):
        return Failure(
            199,
            (
                f"{command}: the Python package pyzipper is not installed",
                f"Install it with: {sys.executable} -m pip install pyzipper",
                "Stata uses the Python shown by -python query-; change it with -set python_exec-",
            ),
        )
    if isinstance(error, PassphraseUnavailable):
        return Failure(
            198,
            (
                f"{command}: no password was given",
                f"Set the environment variable {PASSPHRASE_VARIABLE} or enter one in the pop-up",
            ),
        )
    if isinstance(error, RuntimeError):
        return Failure(499, (f"{command}: wrong password for {archive_path}",))
    if isinstance(error, FileNotFoundError) and command == "encuse":
        return Failure(601, (f"{command}: file {archive_path} not found",))
    return Failure(603, (f"{command}: cannot write {archive_path}: {error}",))


def not_an_archive(command: str, archive_path: str) -> Failure:
    return Failure(
        610,
        (f"{command}: {archive_path} is not an encrypted dataset archive made by encsave",),
    )


def run(command: str, action: str, archive_path: str, plain_path: str) -> Failure | None:
    try:
        pyzipper = importlib.import_module("pyzipper")
    except ImportError as error:
        return failure_for(command, error, archive_path)
    bad_archive = (zipfile.BadZipFile, pyzipper.BadZipFile, KeyError)
    try:
        if action == "load" and not os.path.exists(archive_path):
            raise FileNotFoundError(archive_path)
        passphrase = read_passphrase(confirm=action == "save")
        if action == "save":
            save_archive(plain_path, archive_path, passphrase)
        else:
            load_archive(archive_path, plain_path, passphrase)
    except bad_archive:
        return not_an_archive(command, archive_path)
    except (PassphraseUnavailable, RuntimeError, OSError) as error:
        return failure_for(command, error, archive_path)
    return None


def run_from_stata(command: str, action: str) -> None:
    from sfi import Macro

    failure = run(
        command,
        action,
        Macro.getLocal("archive"),
        Macro.getLocal("plain"),
    )
    if failure is None:
        Macro.setLocal("zipcode", "0")
        return
    Macro.setLocal("zipcode", str(failure.code))
    for position, line in enumerate(failure.lines, start=1):
        Macro.setLocal(f"zipline{position}", line)
    Macro.setLocal("ziplines", str(len(failure.lines)))
