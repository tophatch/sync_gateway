
# This is a test suite to run the SG and SG Accel unit tests against a live Couchbase Server
# bucket (as opposed to walrus).  It works around the "interference" issues that seem to happen
# when trying to run the full test suite (eg, running test.sh) as follows (maybe due to residual objects in Sync Gateway
# memory like timer callbacks)
#
# Regarding maintenance, this might be a temporary script until the interference issues mentioned above
# are solved.  However, if it does become a permanent script, then it should probably be upgraded to
# leverage a tool like https://github.com/ungerik/pkgreflect to discover the list of tests.

set -x
set -e 

# --------------------------------- Sync Gateway tests -----------------------------------------

declare -a arr=(
#    "TestValidateGuestUser"
#    "TestValidateUser"
#    "TestValidateRole"
#    "TestValidateUserEmail"
#    "TestUserPasswords"
#    "TestAuthenticationSpeed"
#    "TestSerializeUser"
#    "TestSerializeRole"
#    "TestUserAccess"
#    "TestGetMissingUser"
#    "TestGetMissingRole"
#    "TestGetGuestUser"
#    "TestSaveUsers"
#    "TestSaveRoles"
#    "TestRebuildUserChannels"
#    "TestRebuildRoleChannels"
#    "TestRebuildChannelsError"
#    "TestRebuildUserRoles"
#    "TestRoleInheritance"
#    "TestRegisterUser"
#    "TestFilterToAvailableSince"
#    "TestFilterToAvailableSince/AllBeforeSince"
#    "TestFilterToAvailableSince/UserBeforeSince"
#    "TestFilterToAvailableSince/RoleGrantBeforeSince"
#    "TestFilterToAvailableSince/RoleGrantAfterSince"
#    "TestFilterToAvailableSince/RoleAndRoleChannelGrantAfterSince_ChannelGrantFirst"
#    "TestFilterToAvailableSince/RoleAndRoleChannelGrantAfterSince_RoleGrantFirst"
#    "TestFilterToAvailableSince/UserGrantOnly"
#    "TestFilterToAvailableSince/RoleGrantBeforeSince#01"
#    "TestFilterToAvailableSince/AllAfterSince"
#    "TestFilterToAvailableSince/AllAfterSinceRoleGrantFirst"
#    "TestFilterToAvailableSince/AllAfterSinceRoleChannelGrantFirst"
#    "TestFilterToAvailableSince/AllAfterSinceNoUserGrant"
#    "TestOIDCUsername"
#    "TestTranscoder"
#    "TestSetGetRaw"
#    "TestAddRaw"
#    "TestBulkGetRaw"
#    "TestWriteCasBasic"
#    "TestWriteCasAdvanced"
#    "TestUpdate"
#    "TestGetAndTouchRaw"
#    "TestCreateBatchesEntries"
#    "TestCreateBatchesKeys"
#    "TestWriteCasXattrSimple"
#    "TestWriteCasXattrUpsert"
#    "TestWriteCasXattrRaw"
#    "TestWriteCasXattrTombstoneResurrect"
#    "TestWriteCasXattrTombstoneXattrUpdate"
#    "TestWriteUpdateXattr"
#    "TestDeleteDocumentHavingXattr"
#    "TestDeleteDocumentUpdateXattr"
#    "TestDeleteDocumentAndXATTR"
#    "TestDeleteDocumentAndUpdateXATTR"
#    "TestRetrieveDocumentAndXattr"
#    "TestApplyViewQueryOptions"
#    "TestApplyViewQueryOptionsWithStrings"
#    "TestTransformBucketCredentials"
#    "TestRollingMeanExpvar"
#    "TestTimingExpvarSequenceOnly"
#    "TestTimingExpvarRangeOnly"
#    "TestTimingExpvarMixed"
#    "TestDedupeTapEventsLaterSeqSameDoc"
#    "TestDedupeNoDedupeDifferentDocs"
#    "TestLRUCache"
#    "TestGetSoftFDLimitWithCurrent"
#    "TestSetFromArray"
#    "TestSet"
#    "TestUnion"
#    "TestSetMarshal"
#    "TestSetUnmarshal"
#    "TestShardedSequenceClock"
#    "TestShardedSequenceClockCasError"
#    "TestShardedClockSizes"
#    "TestShardedClockPartitionBasic"
#    "TestShardedClockPartitionResize"
#    "TestShardedClockPartitionResizeLarge"
#    "TestCompareVbAndSequence"
#    "TestFixJSONNumbers"
#    "TestBackQuotedStrings"
#    "TestCouchbaseUrlWithAuth"
#    "TestCreateDoublingSleeperFunc"
#    "TestRetryLoop"
#    "TestSyncSourceFromURL"
#    "TestValueToStringArray"
#    "TestHighSeqNosToSequenceClock"
#    "TestEmptyLog"
#    "TestAddInOrder"
#    "TestAddOutOfOrder"
#    "TestTruncate"
#    "TestSort"
#    "TestOttoValueToStringArray"
#    "TestJavaScriptWorks"
#    "TestSyncFunction"
#    "TestAccessFunction"
#    "TestSyncFunctionTakesArray"
#    "TestSyncFunctionRejectsInvalidChannels"
#    "TestAccessFunctionRejectsInvalidChannels"
#    "TestAccessFunctionTakesArrayOfUsers"
#    "TestAccessFunctionTakesArrayOfChannels"
#    "TestAccessFunctionTakesArrayOfChannelsAndUsers"
#    "TestAccessFunctionTakesEmptyArrayUser"
#    "TestAccessFunctionTakesEmptyArrayChannels"
#    "TestAccessFunctionTakesNullUser"
#    "TestAccessFunctionTakesNullChannels"
#    "TestAccessFunctionTakesNonChannelsInArray"
#    "TestAccessFunctionTakesUndefinedUser"
#    "TestRoleFunction"
#    "TestInputParse"
#    "TestDefaultChannelMapper"
#    "TestEmptyChannelMapper"
#    "TestChannelMapperUnderscoreLib"
#    "TestChannelMapperReject"
#    "TestChannelMapperThrow"
#    "TestChannelMapperException"
#    "TestPublicChannelMapper"
#    "TestCheckUser"
#    "TestCheckUserArray"
#    "TestCheckRole"
#    "TestCheckRoleArray"
#    "TestCheckAccess"
#    "TestCheckAccessArray"
#    "TestSetFunction"
#    "TestChangedUsers"
#    "TestIsValidChannel"
#    "TestSetFromArray"
#    "TestSetFromArrayWithStar"
#    "TestSetFromArrayError"
#    "TestTimedSetMarshal"
#    "TestTimedSetUnmarshal"
#    "TestEncodeSequenceID"
#    "TestEqualsWithEqualSet"
#    "TestEqualsWithUnequalSet"
#    "TestAttachments"
#    "TestAttachmentForRejectedDocument"
#    "TestSkippedSequenceQueue"
#    "TestLateSequenceHandling"
#    "TestLateSequenceHandlingWithMultipleListeners"
#    "TestChannelCacheBufferingWithUserDoc"
#    "TestChannelCacheBackfill"
#    "TestContinuousChangesBackfill"
#   "TestLowSequenceHandling"
#    "TestLowSequenceHandlingAcrossChannels"
#    "TestLowSequenceHandlingWithAccessGrant"
#    "TestSkippedViewRetrieval"
#    "TestStopChangeCache"
    "TestChannelCacheSize"
    "TestChangesAfterChannelAdded"
    "TestDocDeletionFromChannelCoalescedRemoved"
    "TestDocDeletionFromChannelCoalesced"
    "TestDuplicateDocID"
    "TestLateArrivingSequence"
    "TestLateSequenceAsFirst"
    "TestDuplicateLateArrivingSequence"
    "TestChannelIndexBulkGet10"
    "TestChannelIndexSimpleReadSingle"
    "TestChannelIndexSimpleReadBulk"
    "TestChannelIndexPartitionReadSingle"
    "TestChannelIndexPartitionReadBulk"
    "TestVbucket"
    "TestChannelVbucketMappings"
    "TestDatabase"
    "TestGetDeleted"
    "TestAllDocs"
    "TestUpdatePrincipal"
    "TestConflicts"
    "TestSyncFnOnPush"
    "TestInvalidChannel"
    "TestAccessFunctionValidation"
    "TestAccessFunction"
    "TestDocIDs"
    "TestUpdateDesignDoc"
    "TestImport"
    "TestPostWithExistingId"
    "TestPutWithUserSpecialProperty"
    "TestWithNullPropertyKey"
    "TestPostWithUserSpecialProperty"
    "TestIncrRetrySuccess"
    "TestIncrRetryFail"
    "TestRecentSequenceHistory"
    "TestChannelView"
    "TestQueryAllDocs"
    "TestViewCustom"
    "TestParseXattr"
    "TestParseDocumentCas"
    "TestWebhookString"
    "TestSanitizedUrl"
    "TestDocumentChangeEvent"
    "TestDBStateChangeEvent"
    "TestSlowExecutionProcessing"
    "TestCustomHandler"
    "TestUnhandledEvent"
    "TestWebhookBasic"
    "TestWebhookOldDoc"
    "TestWebhookTimeout"
    "TestUnavailableWebhook"
    "TestIndexBlockCreation"
    "TestIndexBlockStorage"
    "TestDenseBlockSingleDoc"
    "TestDenseBlockMultipleInserts"
    "TestDenseBlockMultipleUpdates"
    "TestDenseBlockRemovalByKey"
    "TestDenseBlockRollbackTo"
    "TestDenseBlockConcurrentUpdates"
    "TestDenseBlockIterator"
    "TestDenseBlockList"
    "TestDenseBlockListBadCas"
    "TestDenseBlockListConcurrentInit"
    "TestDenseBlockListRotate"
    "TestCalculateChangedPartitions"
    "TestRevisionCache"
    "TestLoaderFunction"
    "TestRevTreeUnmarshalOldFormat"
    "TestRevTreeUnmarshal"
    "TestRevTreeMarshal"
    "TestRevTreeAccess"
    "TestRevTreeParentAccess"
    "TestRevTreeGetHistory"
    "TestRevTreeGetLeaves"
    "TestRevTreeForEachLeaf"
    "TestRevTreeAddRevision"
    "TestRevTreeCompareRevIDs"
    "TestRevTreeIsLeaf"
    "TestRevTreeWinningRev"
    "TestPruneRevisions"
    "TestParseRevisions"
    "TestEncodeRevisions"
    "TestTrimEncodedRevisionsToAncestor"
    "TestHashCalculation"
    "TestHashStorage"
    "TestConcurrentHashStorage"
    "TestParseSequenceID"
    "TestMarshalSequenceID"
    "TestSequenceIDUnmarshalJSON"
    "TestMarshalTriggeredSequenceID"
    "TestCompareSequenceIDs"
    "TestShadowerPull"
    "TestShadowerPullWithNotifications"
    "TestShadowerPush"
    "TestShadowerPushEchoCancellation"
    "TestShadowerPullRevisionWithMissingParentRev"
    "TestShadowerPattern"
    "TestUserAPI"
    "TestUserPasswordValidation"
    "TestUserAllowEmptyPassword"
    "TestUserDeleteDuringChangesWithAccess"
    "TestRoleAPI"
    "TestGuestUser"
    "TestSessionTtlGreaterThan30Days"
    "TestSessionExtension"
    "TestSessionAPI"
    "TestFlush"
    "TestDBOfflineSingle"
    "TestDBOfflineConcurrent"
    "TestStartDBOffline"
    "TestDBOffline503Response"
    "TestDBOfflinePutDbConfig"
    "TestDBOfflinePostResync"
    "TestDBOnlineSingle"
    "TestDBOnlineConcurrent"
    "TestSingleDBOnlineWithDelay"
    "TestDBOnlineWithDelayAndImmediate"
    "TestDBOnlineWithTwoDelays"
    "TestPurgeWithBadJsonPayload"
    "TestPurgeWithNonArrayRevisionList"
    "TestPurgeWithEmptyRevisionList"
    "TestPurgeWithGreaterThanOneRevision"
    "TestPurgeWithNonStarRevision"
    "TestPurgeWithStarRevision"
    "TestPurgeWithMultipleValidDocs"
    "TestPurgeWithSomeInvalidDocs"
    "TestReplicateErrorConditions"
    "TestDocumentChangeReplicate"
    "TestRoot"
    "TestDocLifecycle"
    "TestDocEtag"
    "TestDocAttachment"
    "TestDocAttachmentOnRemovedRev"
    "TestDocumentUpdateWithNullBody"
    "TestFunkyDocIDs"
    "TestFunkyDocAndAttachmentIDs"
    "TestCORSOrigin"
    "TestCORSLoginOriginOnSessionPost"
    "TestCORSLoginOriginOnSessionPostNoCORSConfig"
    "TestNoCORSOriginOnSessionPost"
    "TestCORSLogoutOriginOnSessionDelete"
    "TestCORSLogoutOriginOnSessionDeleteNoCORSConfig"
    "TestNoCORSOriginOnSessionDelete"
    "TestManualAttachment"
    "TestManualAttachmentNewDoc"
    "TestBulkDocs"
    "TestBulkDocsEmptyDocs"
    "TestBulkDocsMalformedDocs"
    "TestBulkGetEmptyDocs"
    "TestBulkDocsChangeToAccess"
    "TestBulkDocsNoEdits"
    "TestRevsDiff"
    "TestOpenRevs"
    "TestLocalDocs"
    "TestResponseEncoding"
    "TestLogin"
    "TestReadChangesOptionsFromJSON"
    "TestAccessControl"
    "TestVbSeqAccessControl"
    "TestChannelAccessChanges"
    "TestAccessOnTombstone"
    "TestUserJoiningPopulatedChannel"
    "TestRoleAssignmentBeforeUserExists"
    "TestRoleAccessChanges"
    "TestAllDocsChannelsAfterChannelMove"
    "TestAttachmentsNoCrossTalk"
    "TestOldDocHandling"
    "TestStarAccess"
    "TestCreateTarget"
    "TestBasicAuthWithSessionCookie"
    "TestEventConfigValidationSuccess"
    "TestEventConfigValidationFailure"
    "TestBulkGetRevPruning"
    "TestDocExpiry"
    "TestUnsupportedConfig"
    "TestChangesAccessNotifyInteger"
    "TestChangesNotifyChannelFilter"
    "TestDocDeletionFromChannel"
    "TestPostChangesInteger"
    "TestPostChangesUserTiming"
    "TestPostChangesSinceInteger"
    "TestPostChangesWithQueryString"
    "TestPostChangesChannelFilterInteger"
    "TestPostChangesAdminChannelGrantInteger"
    "TestChangesLoopingWhenLowSequence"
    "TestUnusedSequences"
    "TestChangesActiveOnlyInteger"
    "TestOneShotChangesWithExplicitDocIds"
    "TestMaxSnapshotsRingBuffer"
    "TestGetRestrictedIntQuery"
    "TestParseHTTPRangeHeader"
    "TestSanitizeURL"
    "TestVerifyHTTPSSupport")


# --------------------------------- SG Accel tests -----------------------------------------

declare -a arr_sgaccel=(
    "TestChannelWriterOnly"
    "TestChannelWriterAddSet"
    "TestChannelWriterAddSetMultiBlock"
    "TestChannelWriterClock"
    "TestPartitionStorage"
    "TestChannelStorageCorrectness_BitFlag"
    "TestChannelStorageCorrectness_Dense"
    "TestChannelStorage_Write_Ops_BitFlag"
    "TestChannelStorage_Write_Ops_Dense"
    "TestChannelStorage_Read_Ops_BitFlag"
    "TestChannelStorage_Read_Ops_Dense"
    "TestChangeIndexAddEntry"
    "TestChangeIndexGetChanges"
    "TestChangeIndexConcurrentWriters"
    "TestChangeIndexConcurrentWriterHandover"
    "TestChangeIndexAddSet"
    "TestDocDeletionFromChannel"
    "TestPostChangesClockBasic"
    "TestPostBlockListRotate"
    "TestPostChangesClockAdmin"
    "TestPostChangesSameVbucket"
    "TestPostChangesSinceClock"
    "TestPostChangesChannelFilterClock"
    "TestMultiChannelUserAndDocs"
    "TestDocDeduplication"
    "TestIndexChangesMultipleRevisions"
    "TestPostChangesAdminChannelGrantClock"
    "TestChangesLoopingWhenLowSequence"
    "TestChangesActiveOnlyClock"
    "TestChangesAccessNotifyClock"
    "TestChangesAccessWithLongpoll"
    "TestStorageReaderCache"
    "TestStorageReaderCacheUpdates"
    "TestStorageReaderCacheSingleDocUpdate"
    "TestIndexWriterRollback"
    "TestChangesBackfillOneshot"
    "TestChangesOneshotLimitSyncGrantMixedBackfill"
    "TestChangesOneshotLimitSyncGrantNoBackfill"
    "TestChangesOneshotLimitAdminGrant"
    "TestInterruptedBackfillWithWritesOnly"
    "TestInterruptedBackfillWithWritesAndHistory"
    "TestInterruptedBackfillWithWritesAndGrantVisibility"
    "TestChangesOneshotLimitRoleGrant"
    "TestChangesLongpollLimitSyncRoleChannelGrant"
    "TestChangesLongpollLimitSyncRoleGrant"
    "TestChangesOneshotLimitRoleAdminGrant"
)

# Set the $GOPATH
export GOPATH=`pwd`/godeps

# This env variable causes the unit tests to run against Couchbase Server running on localhost.
# The tests will create any buckets they need on their own.
export SG_TEST_BACKING_STORE=Couchbase

# Run Sync Gateway Tests
for i in "${arr[@]}"
do
    go test -v -run ^"$i"$ github.com/couchbase/sync_gateway/...
done

# Run Sync Gateway Accel tests
for i in "${arr_sgaccel[@]}"
do
    go test -v -run ^"$i"$ github.com/couchbaselabs/sync-gateway-accel/...
done



