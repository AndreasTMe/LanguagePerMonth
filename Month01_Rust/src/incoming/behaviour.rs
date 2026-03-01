use bitmask_enum::bitmask;

#[bitmask(u8)]
pub enum Behaviour {
    NONE = 0,
    HIGH_PRIORITY = 1 << 0,
    LONG_RUNNING = 1 << 1,
    RESOURCE_INTENSIVE = 1 << 2,
    REQUIRES_AFFINITY = 1 << 3,
    RETRYABLE = 1 << 4,
    EXACTLY_ONCE = 1 << 5,
}

impl Behaviour {
    const BEHAVIOURS: [Behaviour; 6] = [
        Behaviour::HIGH_PRIORITY,
        Behaviour::LONG_RUNNING,
        Behaviour::RESOURCE_INTENSIVE,
        Behaviour::REQUIRES_AFFINITY,
        Behaviour::RETRYABLE,
        Behaviour::EXACTLY_ONCE,
    ];

    pub fn get_all() -> &'static [Behaviour] {
        &Self::BEHAVIOURS
    }
}
