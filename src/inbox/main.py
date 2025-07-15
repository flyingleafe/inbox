import argparse
import inotify.adapters as ia
from notifypy import Notify


def watch(args: argparse.Namespace) -> None:
    i = ia.Inotify()
    i.add_watch(args.path)

    for event in i.event_gen(yield_nones=False):
        if event is None:
            continue

        print(event)
        _, type_names, path, filename = event
        n = Notify()
        n.title = "New file"
        n.message = f"{path}/{filename}: {type_names}"
        n.send()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", type=str, default="/home/flyingleafe/Inbox")
    args = parser.parse_args() 
    watch(args)


if __name__ == "__main__":
    main()
