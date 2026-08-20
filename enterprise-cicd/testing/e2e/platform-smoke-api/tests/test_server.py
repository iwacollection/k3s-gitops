from platform_smoke_api.server import Handler


def test_handler_is_defined() -> None:
    assert Handler.__name__ == "Handler"
