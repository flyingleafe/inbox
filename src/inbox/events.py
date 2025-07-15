
from collections.abc import AsyncGenerator, Iterable, Iterator
from dataclasses import dataclass
from enum import Enum
from typing import TypeVar, Any

from asgiref.sync import sync_to_async
from inotify.adapters import INOTIFY_EVENT as INOTIFY_EVENT
from inotify.adapters import Inotify

# Utils

iter_async = sync_to_async(iter)


@sync_to_async
def next_async(it: Iterator[Any]) -> Any:
    try:
        return next(it)
    except StopIteration:
        raise StopAsyncIteration from None


T = TypeVar("T")


def to_async_iter(iterable: Iterable[T]) -> AsyncGenerator[T, None]:
    async def _inner() -> AsyncGenerator[T, None]:
        async_iter = await iter_async(iterable)
        while True:
            try:
                yield await next_async(async_iter)
            except StopAsyncIteration:
                return

    return _inner()


# Events

RawEvent = tuple[INOTIFY_EVENT, list[str], str, str]


class EventType(Enum):
    ADDED = "added"
    REMOVED = "removed"
    MODIFIED = "modified"


@dataclass
class Event:
    path: str
    filename: str
    type: EventType

    def __str__(self) -> str:
        return f"{self.path}/{self.filename}: {self.type}"


def is_valid_event(
    event: RawEvent | None,
) -> bool:
    if event is None:
        return False

    _, type_names, path, filename = event

    if filename == "":      # skip root directory events
        return False

    return True


async def batched_events(inotify: Inotify) -> AsyncGenerator[Event, None]:
    for event in inotify.event_gen(yield_nones=False):
        if event is None:
            continue

        _, type_names, path, filename = event

        if filename == "":      # skip root directory events
            continue

        yield Event(path, filename, EventType(type_names))


