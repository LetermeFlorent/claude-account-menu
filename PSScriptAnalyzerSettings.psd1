@{
  Severity = @("Error", "Warning")
  ExcludeRules = @(
    "PSAvoidUsingWriteHost",
    "PSUseShouldProcessForStateChangingFunctions",
    "PSUseSingularNouns",
    "PSAvoidUsingEmptyCatchBlock",
    "PSReviewUnusedParameter",
    "PSAvoidUsingPlainTextForPassword",
    "PSAvoidInvokingEmptyMembers"
  )
}
