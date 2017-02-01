require "spec_helper"

RSpec.describe OpenelectionMunger::ExportToCsv do
  it "exports a csv" do
    export = OpenelectionMunger::ExportToCsv.new
    #path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "openelections-sources-ks", "Johnson", "2016\ Johnson\,\ KS\ precinct-level\ election\ results.pdf"))
    path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "openelections-sources-ks", "Johnson", "2016_Johnson.pdf"))
    expect(export.convert_to_csv(path)).not_to be nil
  end


end