namespace Workers

open System

type Configuration(args: string[]) =

    static let messageCountArg: string = "--message-count"
    static let threadCountArg: string = "--thread-count"

    let messageCount: int option =
        args
        |> Array.windowed 2
        |> Array.tryPick (fun pair ->
            if pair[0] = messageCountArg then
                match Int32.TryParse(pair[1]) with
                | true, m when m > 0 -> Some m
                | _ -> None
            else
                None)

    let threadCount: int option =
        args
        |> Array.windowed 2
        |> Array.tryPick (fun pair ->
            if pair[0] = threadCountArg then
                match Int32.TryParse(pair[1]) with
                | true, t when t > 0 -> Some t
                | _ -> None
            else
                None)

    do
        if messageCount.IsNone || threadCount.IsNone then
            Console.Error.WriteLine($"Invalid input. Pass required arguments: '{messageCountArg}', '{threadCountArg}'.")

    member _.MessageCount: int =
        if messageCount.IsSome && messageCount.Value > 0 then
            messageCount.Value
        else
            0

    member _.ThreadCount: int =
        if threadCount.IsSome && threadCount.Value > 0 then
            threadCount.Value
        else
            0

    member this.IsValid: bool = this.MessageCount > 0 && this.ThreadCount > 0
