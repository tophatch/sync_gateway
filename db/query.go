package db

import (
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/couchbase/gocb"
	sgbucket "github.com/couchbase/sg-bucket"
	"github.com/couchbase/sync_gateway/base"
	"github.com/couchbase/sync_gateway/channels"
)

// Used for queries that only return doc id
type QueryIdRow struct {
	Id string
}

var QueryAccess = fmt.Sprintf(
	"SELECT $sync.access.`$userName` as `value` "+
		"FROM `%s` "+
		"WHERE any op in object_pairs($sync.access) satisfies op.name = '$userName' end;",
	base.BucketQueryToken)

var QueryRoleAccess = fmt.Sprintf(
	"SELECT $sync.role_access.`$userName` as `value` "+
		"FROM `%s` "+
		"WHERE any op in object_pairs($sync.role_access) satisfies op.name = '$userName' end;",
	base.BucketQueryToken)

// QueryAccessRow used for response from both QueryAccess and QueryRoleAccess
type QueryAccessRow struct {
	Value channels.TimedSet
}

var QueryChannels = fmt.Sprintf(
	"SELECT [op.name, LEAST($sync.sequence, op.val.seq),IFMISSING(op.val.rev,null),IFMISSING(op.val.del,null)][1] AS seq, "+
		"[op.name, LEAST($sync, op.val.seq),IFMISSING(op.val.rev,null),IFMISSING(op.val.del,null)][2] AS rRev, "+
		"[op.name, LEAST($sync, op.val.seq),IFMISSING(op.val.rev,null),IFMISSING(op.val.del,null)][3] AS rDel, "+
		"$sync.rev AS rev, "+
		"$sync.flags AS flags, "+
		"META(`%s`).id AS id "+
		"FROM `%s` "+
		"UNNEST OBJECT_PAIRS($sync.channels) AS op "+
		"WHERE [op.name, LEAST($sync.sequence, op.val.seq),IFMISSING(op.val.rev,null),IFMISSING(op.val.del,null)]  BETWEEN  [$channelName, $startSeq] AND [$channelName, $endSeq]",
	base.BucketQueryToken, base.BucketQueryToken)

var QueryStarChannel = fmt.Sprintf(
	"SELECT $sync.sequence AS seq, "+
		"$sync.rev AS rev, "+
		"$sync.flags AS flags, "+
		"META(`%s`).id AS id "+
		"FROM `%s`"+
		"WHERE $sync.sequence >= $startSeq AND $sync.sequence < $endSeq "+
		"AND META().id NOT LIKE '%s'",
	base.BucketQueryToken, base.BucketQueryToken, SyncDocWildcard)

type QueryChannelsRow struct {
	Id         string `json:"id,omitempty"`
	Rev        string `json:"rev,omitempty"`
	Sequence   uint64 `json:"seq,omitempty"`
	Flags      uint8  `json:"flags,omitempty"`
	RemovalRev string `json:"rRev,omitempty"`
	RemovalDel bool   `json:"rDel,omitempty"`
}

var QueryPrincipals = fmt.Sprintf(
	"SELECT META(`%s`).id "+
		"FROM `%s` "+
		"WHERE META(`%s`).id LIKE '%s' "+
		"AND (META(`%s`).id LIKE '%s' "+
		"OR META(`%s`).id LIKE '%s')",
	base.BucketQueryToken, base.BucketQueryToken, base.BucketQueryToken, SyncDocWildcard, base.BucketQueryToken, `\\_sync:user:%`, base.BucketQueryToken, `\\_sync:role:%`)

var QuerySessions = fmt.Sprintf(
	"SELECT META(`%s`).id "+
		"FROM `%s` "+
		"WHERE META(`%s`).id LIKE '%s' "+
		"AND META(`%s`).id LIKE '%s' "+
		"AND username = $userName",
	base.BucketQueryToken, base.BucketQueryToken, base.BucketQueryToken, SyncDocWildcard, base.BucketQueryToken, `\\_sync:session:%`)

var QueryTombstones = fmt.Sprintf(
	"SELECT META(`%s`).id "+
		"FROM `%s` "+
		"WHERE $sync.tombstoned_at BETWEEN 0 AND $olderThan",
	base.BucketQueryToken, base.BucketQueryToken)

// QueryResync and QueryImport both use IndexAllDocs.  If these need to be revisited for performance reasons,
// they could be retooled to use covering indexes, where the id filtering is done at indexing time.  Given that this code
// doesn't even do pagination currently, it's likely that this functionality should just be replaced by an ad-hoc
// DCP stream.
var QueryResync = fmt.Sprintf(
	"SELECT META(`%s`).id "+
		"FROM `%s` "+
		"WHERE META(`%s`).id NOT LIKE '%s' "+
		"AND $sync IS NOT MISSING",
	base.BucketQueryToken, base.BucketQueryToken, base.BucketQueryToken, SyncDocWildcard)

var QueryImport = fmt.Sprintf(
	"SELECT META(`%s`).id "+
		"FROM `%s` "+
		"WHERE META(`%s`).id NOT LIKE '%s' "+
		"AND $sync.sequence IS MISSING ",
	base.BucketQueryToken, base.BucketQueryToken, base.BucketQueryToken, SyncDocWildcard)

// QueryAllDocs is using the primary index.  We currently don't have a performance-tuned use of AllDocs today - if needed,
// should create a custom index
var QueryAllDocs = fmt.Sprintf(
	"SELECT META(`%s`).id as id, "+
		"$sync.rev as r, "+
		"$sync.sequence as s, "+
		"$sync.channels as c "+
		"FROM `%s` "+
		"WHERE META(`%s`).id NOT LIKE '%s' "+
		"AND $sync IS NOT MISSING "+
		"AND ($sync.flags IS MISSING OR BITTEST($sync.flags,1) = false)",
	base.BucketQueryToken, base.BucketQueryToken, base.BucketQueryToken, SyncDocWildcard)

// Query Parameters used as parameters in prepared statements.  Note that these are hardcoded into the query definitions above,
// for improved query readability.
const (
	QueryParamChannelName = "channelName"
	QueryParamStartSeq    = "startSeq"
	QueryParamEndSeq      = "endSeq"
	QueryParamUserName    = "userName"
	QueryParamOlderThan   = "olderThan"
)

// Query to compute the set of channels granted to the specified user via the Sync Function
func (context *DatabaseContext) QueryAccess(username string) (sgbucket.QueryResultIterator, error) {

	// View Query
	if context.Options.UseViews {
		opts := map[string]interface{}{"stale": false, "key": username}
		return context.Bucket.ViewQuery(DesignDocSyncGateway(), ViewAccess, opts)
	}

	if username == "" {
		base.Warn("QueryAccess called with empty username - returning empty result iterator")
		return &EmptyResultIterator{}, nil
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform access N1QL query on non-Couchbase bucket.")
	}

	// Can't use prepared query because username is in select clause
	accessQueryStatement := replaceSyncTokensQuery(QueryAccess, context.UseXattrs())
	accessQueryStatement = strings.Replace(accessQueryStatement, "$"+QueryParamUserName, username, -1)
	return gocbBucket.Query(accessQueryStatement, nil, gocb.RequestPlus, true)
}

// Query to compute the set of roles granted to the specified user via the Sync Function
func (context *DatabaseContext) QueryRoleAccess(username string) (sgbucket.QueryResultIterator, error) {

	// View Query
	if context.Options.UseViews {
		opts := map[string]interface{}{"stale": false, "key": username}
		return context.Bucket.ViewQuery(DesignDocSyncGateway(), ViewRoleAccess, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform role access N1QL query on non-Couchbase bucket.")
	}

	if username == "" {
		base.Warn("QueryRoleAccess called with empty username")
		return &EmptyResultIterator{}, nil
	}

	// Can't use prepared query because username is in select clause
	accessQueryStatement := replaceSyncTokensQuery(QueryRoleAccess, context.UseXattrs())
	accessQueryStatement = strings.Replace(accessQueryStatement, "$"+QueryParamUserName, username, -1)
	return gocbBucket.Query(accessQueryStatement, nil, gocb.RequestPlus, true)
}

// Query to compute the set of documents assigned to the specified channel within the sequence range
func (context *DatabaseContext) QueryChannels(channelName string, startSeq uint64, endSeq uint64, limit int) (sgbucket.QueryResultIterator, error) {

	if context.Options.UseViews {
		opts := changesViewOptions(channelName, startSeq, endSeq, limit)
		return context.Bucket.ViewQuery(DesignDocSyncGateway(), ViewChannels, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform channels N1QL query on non-Couchbase bucket.")
	}

	// Standard channel index/query doesn't support the star channel.  For star channel queries, QueryStarChannel
	// (which is backed by IndexAllDocs) is used.  The QueryStarChannel result schema is a subset of the
	// QueryChannels result schema (removal handling isn't needed for the star channel).
	var channelQueryStatement string
	if channelName == "*" {
		channelQueryStatement = replaceSyncTokensQuery(QueryStarChannel, context.UseXattrs())
	} else {
		channelQueryStatement = replaceSyncTokensQuery(QueryChannels, context.UseXattrs())
	}

	if limit > 0 {
		channelQueryStatement = fmt.Sprintf("%s LIMIT %d", channelQueryStatement, limit)
	}

	// Channel queries use a prepared query
	params := make(map[string]interface{}, 3)
	params[QueryParamChannelName] = channelName
	params[QueryParamStartSeq] = startSeq
	if endSeq == 0 {
		// If endSeq isn't defined, set to max uint64
		endSeq = math.MaxUint64
	} else {
		// channels query isn't based on inclusive end - add one to ensure complete result set
		endSeq++
	}
	params[QueryParamEndSeq] = endSeq
	return gocbBucket.Query(channelQueryStatement, params, gocb.RequestPlus, true)
}

func (context *DatabaseContext) QueryImport(hasSyncData bool) (sgbucket.QueryResultIterator, error) {

	if context.Options.UseViews {
		opts := Body{"stale": false, "reduce": false}
		if hasSyncData {
			opts["startkey"] = []interface{}{true}
		} else {
			opts["endkey"] = []interface{}{true}
			opts["inclusive_end"] = false
		}
		return context.Bucket.ViewQuery(DesignDocSyncHousekeeping(), ViewImport, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform channels N1QL query on non-Couchbase bucket.")
	}

	var importQueryStatement string
	if hasSyncData {
		importQueryStatement = replaceSyncTokensQuery(QueryResync, context.UseXattrs())
	} else {
		importQueryStatement = replaceSyncTokensQuery(QueryImport, context.UseXattrs())
	}

	return gocbBucket.Query(importQueryStatement, nil, gocb.RequestPlus, true)
}

// Query to retrieve the set of user and role doc ids, using the primary index
func (context *DatabaseContext) QueryPrincipals() (sgbucket.QueryResultIterator, error) {

	// View Query
	if context.Options.UseViews {
		opts := map[string]interface{}{"stale": false}
		return context.Bucket.ViewQuery(DesignDocSyncGateway(), ViewPrincipals, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform principals N1QL query on non-Couchbase bucket.")
	}

	return gocbBucket.Query(QueryPrincipals, nil, gocb.RequestPlus, false)
}

// Query to retrieve the set of user and role doc ids, using the primary index
func (context *DatabaseContext) QuerySessions(userName string) (sgbucket.QueryResultIterator, error) {

	// View Query
	if context.Options.UseViews {
		opts := Body{"stale": false}
		opts["startkey"] = userName
		opts["endkey"] = userName
		return context.Bucket.ViewQuery(DesignDocSyncHousekeeping(), ViewSessions, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform sessions N1QL query on non-Couchbase bucket.")
	}

	params := make(map[string]interface{}, 1)
	params[QueryParamUserName] = userName
	return gocbBucket.Query(QuerySessions, params, gocb.RequestPlus, false)
}

type AllDocsViewQueryRow struct {
	Key   string
	Value struct {
		RevID    string   `json:"r"`
		Sequence uint64   `json:"s"`
		Channels []string `json:"c"`
	}
}

type AllDocsIndexQueryRow struct {
	Id       string
	RevID    string              `json:"r"`
	Sequence uint64              `json:"s"`
	Channels channels.ChannelMap `json:"c"`
}

// AllDocs returns all non-deleted documents in the bucket between startKey and endKey
func (context *DatabaseContext) QueryAllDocs(startKey string, endKey string) (sgbucket.QueryResultIterator, error) {

	// View Query
	if context.Options.UseViews {
		opts := Body{"stale": false, "reduce": false}
		if startKey != "" {
			opts["startkey"] = startKey
		}
		if endKey != "" {
			opts["endkey"] = endKey
		}
		return context.Bucket.ViewQuery(DesignDocSyncHousekeeping(), ViewAllDocs, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform AllDocs N1QL query on non-Couchbase bucket.")
	}

	allDocsQueryStatement := replaceSyncTokensQuery(QueryAllDocs, context.UseXattrs())
	if startKey != "" {
		allDocsQueryStatement = fmt.Sprintf("%s AND META().id >= '%s'", allDocsQueryStatement, startKey)
	}
	if endKey != "" {
		allDocsQueryStatement = fmt.Sprintf("%s AND META().id <= '%s'", allDocsQueryStatement, endKey)
	}
	return gocbBucket.Query(allDocsQueryStatement, nil, gocb.RequestPlus, false)

}

func (context *DatabaseContext) QueryTombstones(olderThan time.Time) (sgbucket.QueryResultIterator, error) {

	// View Query
	if context.Options.UseViews {
		opts := Body{"stale": "ok"}
		opts["startkey"] = 1
		opts["endkey"] = olderThan.Unix()
		return context.Bucket.ViewQuery(DesignDocSyncHousekeeping(), ViewTombstones, opts)
	}

	// N1QL Query
	gocbBucket, ok := context.Bucket.(*base.CouchbaseBucketGoCB)
	if !ok {
		return nil, errors.New("Cannot perform tombstones N1QL query on non-Couchbase bucket.")
	}

	tombstoneQueryStatement := replaceSyncTokensQuery(QueryTombstones, context.UseXattrs())
	params := make(map[string]interface{}, 1)
	params[QueryParamOlderThan] = olderThan.Unix()
	return gocbBucket.Query(tombstoneQueryStatement, params, gocb.NotBounded, false)
}

func changesViewOptions(channelName string, startSeq, endSeq uint64, limit int) Body {
	endKey := []interface{}{channelName, endSeq}
	if endSeq == 0 {
		endKey[1] = map[string]interface{}{} // infinity
	}
	optMap := Body{
		"stale":    false,
		"startkey": []interface{}{channelName, startSeq},
		"endkey":   endKey,
	}
	if limit > 0 {
		optMap["limit"] = limit
	}
	return optMap
}

type EmptyResultIterator struct{}

func (e *EmptyResultIterator) One(valuePtr interface{}) error {
	return nil
}

func (e *EmptyResultIterator) Next(valuePtr interface{}) bool {
	return false
}

func (e *EmptyResultIterator) NextBytes() []byte {
	return []byte{}
}

func (e *EmptyResultIterator) Close() error {
	return nil
}
