use std::env::Args;
use std::io::{Error, ErrorKind};

const MESSAGE_COUNT_ARG: &str = "--message-count";
const THREAD_COUNT_ARG: &str = "--thread-count";

pub struct Configuration {
    message_count: Option<usize>,
    thread_count: Option<usize>,
}

impl Configuration {
    pub fn new(args: Args) -> std::io::Result<Self> {
        if args.len() < 4 {
            return Err(Error::new(
                ErrorKind::InvalidInput,
                format!(
                    "Invalid input. Pass required arguments: '{MESSAGE_COUNT_ARG}', '{THREAD_COUNT_ARG}'."
                ),
            ));
        }

        let mut message_count: Option<usize> = None;
        let mut thread_count: Option<usize> = None;

        let mut it = args.skip(1);

        while let Some(flag) = it.next() {
            match flag.as_str() {
                MESSAGE_COUNT_ARG => {
                    message_count = it.next().and_then(|v| v.parse::<usize>().ok());
                }
                THREAD_COUNT_ARG => {
                    thread_count = it.next().and_then(|v| v.parse::<usize>().ok());
                }
                _ => continue,
            }
        }

        Ok(Self {
            message_count,
            thread_count,
        })
    }

    pub fn get_message_count(&self) -> usize {
        self.message_count.unwrap_or(0)
    }

    pub fn get_thread_count(&self) -> usize {
        self.thread_count.unwrap_or(0)
    }
}
