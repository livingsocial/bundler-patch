require_relative '../spec_helper'

describe Scanner do
  it 'should support custom database for internal gems'

  it 'should have existing stuff tested' # i should backfill some testing here eventually. first shot easy enough to 'test' manually

  it 'could re-detect unfixed stuff after bundle audit and notify'

  it 'could attempt to discover requirements that will not allow an upgrade'
    # e.g. if foo requires a specific version of bar that won't allow bar to be patched, then either notify or try
    # to bundle update foo as well. maybe support that as an aggressive option or somesuch.
end
