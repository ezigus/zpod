#if canImport(Combine)
  @_exported @preconcurrency import Combine
#else
  @_exported import OpenCombine
  @_exported import OpenCombineDispatch
  @_exported import OpenCombineFoundation
#endif
