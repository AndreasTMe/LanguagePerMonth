mod configuration;
mod incoming;
mod worker;

use crate::configuration::Configuration;
use crate::incoming::work::Work;
use crate::worker::Worker;
use std::env;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let configuration = match Configuration::new(env::args()) {
        Ok(config) => {
            println!("Valid configuration received. Starting...");
            config
        }
        Err(err) => {
            println!("{} Shutting down...", err);
            return Ok(());
        }
    };

    let message_count = configuration.get_message_count();
    let thread_count = configuration.get_thread_count();

    let cancel = CancellationToken::new();
    let cancel_on_ctrl_c = cancel.clone();
    tokio::spawn(async move {
        let _ = tokio::signal::ctrl_c().await;
        cancel_on_ctrl_c.cancel();
    });

    let (sender, receiver) = mpsc::channel(message_count);

    for i in 0..message_count {
        let work = Work::create(i);
        if let Err(err) = sender.send(work).await {
            println!("Error when sending message: {}", err);
        }
    }
    drop(sender);

    let shared_receiver = Arc::new(Mutex::new(receiver));

    let mut workers = tokio::task::JoinSet::new();
    for _ in 0..thread_count {
        let mut worker = Worker::create(shared_receiver.clone());
        let cancel_clone = cancel.clone();
        workers.spawn(async move {
            worker.execute(cancel_clone).await;
        });
    }

    while let Some(_res) = workers.join_next().await {
        // ignore per-worker results for now
    }

    println!("Work completed. Shutting down...");

    Ok(())
}
