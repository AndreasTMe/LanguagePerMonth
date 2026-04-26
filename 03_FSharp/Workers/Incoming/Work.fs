namespace Workers.Incoming

open System
open Workers.Incoming

[<Struct>]
type Work =
    { Id: int
      ExecutionModel: ExecutionModel
      Behaviour: Behaviour }

    static let executionModels: ExecutionModel[] = Enum.GetValues<ExecutionModel>()

    static let behaviours: Behaviour[] = Enum.GetValues<Behaviour>()

    static member public Create(id: int) : Work =
        { Id = id
          ExecutionModel = Work.PickRandomExecutionModel()
          Behaviour = Work.PickRandomBehaviour() }

    static member private PickRandomExecutionModel() : ExecutionModel =
        executionModels[Random.Shared.Next(executionModels.Length)]

    static member private PickRandomBehaviour() : Behaviour =
        let singles: byte[] =
            behaviours
            |> Array.choose (fun value ->
                let b = byte value

                if b = 0uy then
                    None
                else
                    let x = int b
                    if (x &&& (x - 1)) = 0 then Some b else None)

        let mask: byte =
            singles
            |> Array.fold (fun acc b -> if Random.Shared.Next(2) = 0 then acc ||| b else acc) 0uy

        // Ensure we don't end up with "None" (0) too often.
        let finalMask =
            if mask = 0uy && singles.Length > 0 then
                singles[Random.Shared.Next(singles.Length)]
            else
                mask

        LanguagePrimitives.EnumOfValue finalMask
