pub const SerializeError = error{
    MandatoryFieldMissed,
    OptionalFieldMissed,
    CorruptedArchive,
    NotEnoughMemory,
    UnexpectedEnd,
    InvalidSize,
    WriteError,
    ReadError,
    Eof,
    EndOfArray,
    EndOfObject,
    UnknownError
};