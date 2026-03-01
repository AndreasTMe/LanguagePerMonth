using System;
using System.Collections.Generic;

namespace Workers.Incoming;

internal readonly record struct Work
{
    private static readonly ExecutionModel[] ExecutionModels = Enum.GetValues<ExecutionModel>();
    private static readonly Behaviour[]      Behaviours      = Enum.GetValues<Behaviour>();

    public int Id { get; private init; }

    public ExecutionModel ExecutionModel { get; private init; }

    public Behaviour Behaviour { get; private init; }

    public static Work Create(int id) =>
        new()
        {
            Id             = id,
            ExecutionModel = PickRandomExecutionModel(),
            Behaviour      = PickRandomBehaviour()
        };

    private static ExecutionModel PickRandomExecutionModel() =>
        ExecutionModels[Random.Shared.Next(ExecutionModels.Length)];

    private static Behaviour PickRandomBehaviour()
    {
        ulong mask    = 0;
        var   singles = new List<byte>(Behaviours.Length);

        foreach (var value in Behaviours)
        {
            var bits = (byte)value;

            if (bits == 0)
            {
                continue;
            }

            // Only treat power-of-two values as "atomic" flags.
            if ((bits & (bits - 1)) != 0)
            {
                continue;
            }

            singles.Add(bits);

            if (Random.Shared.Next(2) == 0)
            {
                mask |= bits;
            }
        }

        // Ensure we don't end up with "None" (0) too often.
        if (mask == 0 && singles.Count > 0)
        {
            mask = singles[Random.Shared.Next(singles.Count)];
        }

        return (Behaviour)mask;
    }
}