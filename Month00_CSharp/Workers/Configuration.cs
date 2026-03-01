using System;

namespace Workers;

internal readonly record struct Configuration
{
    private const string MessageCountArg = "--message-count";
    private const string ThreadCountArg  = "--thread-count";

    public int MessageCount { get; init; }
    public int ThreadCount  { get; init; }

    public bool IsValid => MessageCount > 0 && ThreadCount > 0;

    public Configuration(string[] args)
    {
        if (args is not { Length: >= 4 })
        {
            Console.Error.WriteLine(
                $"Invalid input. Pass required arguments: '{MessageCountArg}', '{ThreadCountArg}'.");
            return;
        }

        for (var i = 0; i < args.Length && i + 1 < args.Length; i += 2)
        {
            switch (args[i])
            {
                case MessageCountArg:
                    MessageCount = int.TryParse(args[i + 1], out var m) ? m : 0;
                    break;
                case ThreadCountArg:
                    ThreadCount = int.TryParse(args[i + 1], out var t) ? t : 0;
                    break;
                default:
                    continue;
            }
        }
    }
}