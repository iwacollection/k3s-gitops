from platform_fixture import health


def test_health() -> None:
    assert health() == "python-build-profile-ok"
