use crate::incoming::behaviour::Behaviour;
use crate::incoming::execution_model::ExecutionModel;
use rand::RngExt;

pub struct Work {
    id: usize,
    execution_model: ExecutionModel,
    behaviour: Behaviour,
}

impl Work {
    pub fn create(id: usize) -> Work {
        Work {
            id,
            execution_model: Self::pick_random_execution_model(),
            behaviour: Self::pick_random_behaviour(),
        }
    }

    pub fn get_id(&self) -> usize {
        self.id
    }
    pub fn get_execution_model(&self) -> ExecutionModel {
        self.execution_model
    }
    pub fn get_behaviour(&self) -> Behaviour {
        self.behaviour
    }

    fn pick_random_execution_model() -> ExecutionModel {
        let slice = ExecutionModel::get_all();
        let mut rng = rand::rng();
        slice[rng.random_range(0..slice.len())]
    }

    fn pick_random_behaviour() -> Behaviour {
        let mut mask: u8 = 0;
        let mut rng = rand::rng();
        let mut singles: Vec<u8> = Vec::new();

        for value in Behaviour::get_all() {
            let bits = value.bits();
            if bits == 0 {
                continue;
            }

            // Only treat power-of-two values as "atomic" flags.
            if (bits & (bits - 1)) != 0 {
                continue;
            }

            singles.push(bits);

            if rng.random_range(0..2) == 0 {
                mask |= bits;
            }
        }

        // Ensure we don't end up with "NONE" (0) too often.
        if mask == 0 && !singles.is_empty() {
            mask = singles[rng.random_range(0..singles.len())];
        }

        Behaviour::from(mask)
    }
}
