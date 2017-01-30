require "spec_helper"

RSpec.describe OpenelectionMunger::ExportToCsv do
  it "exports a csv" do
    export = OpenelectionMunger::ExportToCsv.new
    expect(export.convert_to_csv).not_to be nil
  end


end