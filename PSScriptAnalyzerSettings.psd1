@{
  Severity = @("Error", "Warning")
  ExcludeRules = @(
    "PSAvoidUsingWriteHost",
    "PSUseShouldProcessForStateChangingFunctions",
    "PSUseSingularNouns",
    "PSReviewUnusedParameter",
    "PSAvoidUsingPlainTextForPassword",
    "PSAvoidInvokingEmptyMembers"
  )
}
