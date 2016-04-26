require_relative '../spec_helper'

describe GemsToPatchReconciler do
  def names_to_patches(names)
    names.map { |n| GemPatch.new(gem_name: n) }
  end

  def reconciler(vuln_names, requested_names=[])
    @vulnerable_patches = names_to_patches(Array(vuln_names))
    GemsToPatchReconciler.new(@vulnerable_patches, names_to_patches(Array(requested_names)))
  end

  it 'should do nothing if nothing requested' do
    r = reconciler('foo')
    r.reconciled_patches.length.should == 0
    # empty will signal to Bundler to update _all_
  end

  it 'should not include non-requested vulnerable gems' do
    r = reconciler('foo', 'bar')
    r.reconciled_patches.length.should == 1
    r.reconciled_patches.first.gem_name.should == 'bar'

    @vulnerable_patches.length.should == 0
  end

  it 'should include requested vulnerable gems' do
    r = reconciler('foo', %w(foo bar))
    r.reconciled_patches.length.should == 2
    r.reconciled_patches.first.gem_name.should == 'foo'
    r.reconciled_patches.last.gem_name.should == 'bar'

    @vulnerable_patches.length.should == 1
  end
end
