#!/usr/bin/env python3
"""Exercise task row-level security with two users and an anonymous client."""

import getpass
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "env.dev.json"


class SecurityTestFailure(Exception):
    pass


def request(method, path, *, api_key, token=None, body=None, prefer=None):
    headers = {"apikey": api_key}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        headers["Content-Type"] = "application/json"
    if prefer is not None:
        headers["Prefer"] = prefer
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"{BASE_URL}{path}", data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            payload = response.read()
            return response.status, json.loads(payload) if payload else None
    except urllib.error.HTTPError as error:
        payload = error.read()
        try:
            result = json.loads(payload) if payload else None
        except json.JSONDecodeError:
            result = None
        return error.code, result


def sign_in(email, password, api_key):
    status, result = request(
        "POST",
        "/auth/v1/token?grant_type=password",
        api_key=api_key,
        body={"email": email, "password": password},
    )
    token = result.get("access_token") if isinstance(result, dict) else None
    if status != 200 or not token:
        raise SecurityTestFailure(
            f"Could not sign in test user (HTTP {status}); check account and confirmation."
        )
    return token


def require(condition, message):
    if not condition:
        raise SecurityTestFailure(message)
    print(f"PASS: {message}")


def task_request(method, task_id, *, api_key, token=None, body=None):
    query = urllib.parse.urlencode(
        {"id": f"eq.{task_id}", "select": "id,title"}
    )
    return request(
        method,
        f"/rest/v1/tasks?{query}",
        api_key=api_key,
        token=token,
        body=body,
        prefer="return=representation",
    )


def main():
    global BASE_URL
    if not CONFIG_PATH.is_file():
        raise SecurityTestFailure(
            "env.dev.json is missing; copy env.example.json and provide the dev project values."
        )
    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        raise SecurityTestFailure("env.dev.json is unreadable or invalid JSON.") from None

    BASE_URL = config.get("SUPABASE_URL", "").rstrip("/")
    api_key = config.get("SUPABASE_ANON_KEY", "")
    if not BASE_URL or not api_key:
        raise SecurityTestFailure(
            "env.dev.json must contain SUPABASE_URL and SUPABASE_ANON_KEY."
        )

    print("Use two existing, confirmed, non-privileged Supabase test accounts.")
    email_a = input("User A email: ").strip()
    password_a = getpass.getpass("User A password: ")
    email_b = input("User B email: ").strip()
    password_b = getpass.getpass("User B password: ")
    if not all((email_a, password_a, email_b, password_b)):
        raise SecurityTestFailure("Both test accounts require an email and password.")

    token_a = sign_in(email_a, password_a, api_key)
    token_b = sign_in(email_b, password_b, api_key)
    task_id = str(uuid.uuid4())
    title = f"rls-test-{task_id}"
    query = urllib.parse.urlencode({"id": f"eq.{task_id}", "select": "id,title"})

    status, inserted = request(
        "POST",
        "/rest/v1/tasks?select=id,title",
        api_key=api_key,
        token=token_a,
        body={"id": task_id, "title": title},
        prefer="return=representation",
    )
    require(status == 201 and isinstance(inserted, list) and len(inserted) == 1,
            "User A can create a task.")

    try:
        status, own_rows = task_request(
            "GET", task_id, api_key=api_key, token=token_a
        )
        require(status == 200 and len(own_rows or []) == 1,
                "User A can read their task.")

        status, rows_b = task_request(
            "GET", task_id, api_key=api_key, token=token_b
        )
        require(status == 200 and rows_b == [],
                "User B cannot read User A's task.")

        status, changed_b = task_request(
            "PATCH",
            task_id,
            api_key=api_key,
            token=token_b,
            body={"title": "unauthorized-change"},
        )
        require(status in (200, 204) and changed_b in (None, []),
                "User B cannot update User A's task.")

        status, removed_b = task_request(
            "DELETE", task_id, api_key=api_key, token=token_b
        )
        require(status in (200, 204) and removed_b in (None, []),
                "User B cannot delete User A's task.")

        for method, body, label in (
            ("GET", None, "read"),
            ("PATCH", {"title": "anonymous-change"}, "update"),
            ("DELETE", None, "delete"),
        ):
            status, result = task_request(
                method, task_id, api_key=api_key, body=body
            )
            denied = status in (401, 403) or (
                status == 200 and result == []
            ) or (status == 204 and result is None)
            require(denied, f"Unauthenticated client cannot {label} tasks.")

        status, final_rows = task_request(
            "GET", task_id, api_key=api_key, token=token_a
        )
        require(
            status == 200
            and len(final_rows or []) == 1
            and final_rows[0].get("title") == title,
            "User A's task remains unchanged after denied attempts.",
        )
    finally:
        task_request("DELETE", task_id, api_key=api_key, token=token_a)

    print("RLS isolation checks completed.")


if __name__ == "__main__":
    try:
        main()
    except SecurityTestFailure as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
    except (OSError, TimeoutError, urllib.error.URLError):
        print("FAIL: Supabase request failed; check network and project availability.",
              file=sys.stderr)
        sys.exit(1)
