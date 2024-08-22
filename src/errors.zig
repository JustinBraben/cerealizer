pub const SerializeError = error{
    NoError,
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