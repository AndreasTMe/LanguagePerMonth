open System
open System.Threading
open System.Threading.Channels
open System.Threading.Tasks
open Workers
open Workers.Incoming

[<EntryPoint>]
let main (args: string[]) : int =
    use cts = new CancellationTokenSource()

    let handler =
        ConsoleCancelEventHandler(fun _ eventArgs ->
            try
                cts.Cancel()
            with :? ObjectDisposedException ->
                () // ignore

            eventArgs.Cancel <- true)

    Console.CancelKeyPress.AddHandler(handler)

    try
        let config = Configuration(args)

        if not config.IsValid then
            Console.Error.WriteLine("Invalid configuration received. Shutting down...")
            -1
        else
            Console.WriteLine("Valid configuration received. Starting...")

            let channel =
                Channel.CreateBounded<Work>(
                    BoundedChannelOptions(config.MessageCount, SingleReader = false, SingleWriter = true)
                )

            let rec produceWork index =
                task {
                    if index < config.MessageCount then
                        do! channel.Writer.WriteAsync(Work.Create(index), cts.Token)
                        do! produceWork (index + 1)
                    else
                        channel.Writer.Complete()
                }

            let run () =
                task {
                    let producer = produceWork 0

                    let consumers =
                        Array.init config.ThreadCount (fun _ -> Worker(channel.Reader).Execute(cts.Token))

                    do! Task.WhenAll(Array.append [| producer :> Task |] consumers)
                    Console.WriteLine("Work completed. Shutting down...")
                    return 0
                }

            run () |> Async.AwaitTask |> Async.RunSynchronously
    finally
        Console.CancelKeyPress.RemoveHandler(handler)
