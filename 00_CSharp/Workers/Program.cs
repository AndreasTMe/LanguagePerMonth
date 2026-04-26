using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;
using Workers;
using Workers.Incoming;

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, eventArgs) =>
{
    try
    {
        cts.Cancel();
    }
    catch (ObjectDisposedException)
    {
        // ignore
    }
    finally
    {
        eventArgs.Cancel = true;
    }
};

var configuration = new Configuration(args);
if (!configuration.IsValid)
{
    Console.Error.WriteLine("Invalid configuration received. Shutting down...");
    return -1;
}

Console.WriteLine("Valid configuration received. Starting...");

var channel = Channel.CreateBounded<Work>(
    new BoundedChannelOptions(configuration.MessageCount)
    {
        SingleReader = false,
        SingleWriter = true
    });

for (var i = 0; i < configuration.MessageCount; i++)
{
    await channel.Writer.WriteAsync(Work.Create(i), cts.Token);
}
channel.Writer.Complete();

var tasks = new List<Task>();
for (var i = 0; i < configuration.ThreadCount; i++)
{
    var worker = new Worker(channel.Reader);
    tasks.Add(worker.Execute(cts.Token));
}

await Task.WhenAll(tasks);

Console.WriteLine("Work completed. Shutting down...");

return 0;