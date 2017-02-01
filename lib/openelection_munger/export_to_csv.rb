require 'open-uri'
require 'pdf/reader'
require 'pathname'
require 'csv'

module OpenelectionMunger
class ExportToCsv
  def initialize
    @county = 'Johnson'
    @precinct = '' # from line 
    @office = '' # From page heading 
    @district = '' # From page heading for Reps
    @party = '' # From Column heading
    @candidates = Array.new # From Column heading
    @votes = '' # From line
    @registered_voters = '' # From line
    @set_break = false

    load_party_affiliation 
  end

  def load_party_affiliation 
    begin
      CSV::Converters[:blank_to_nil] = lambda do |field|
        field && field.empty? ? nil : field
      end
      candidates = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "states", "kansas", "candidates.csv"))
      csv = CSV.read(candidates, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
      csv_hash = csv.map {|row| row.to_h }
      @party_affiliation = Hash.new
      csv_hash.each do |row|
        candidate = row[:candidate].gsub(/\./, '').rstrip
        @party_affiliation[candidate] = row[:party].rstrip
      end
    rescue StandardError => e
      $stderr.puts "CSV failed (#{e.message})"
    end
  end


  # lol, 1-based Array... deal with it
  def candidate_name_scrub (line, matches)
    candidates = Array.new
    case line
      when /CLINTON/ # List full names
        @candidates[1] = "Hillary Rodham Clinton / Timothy Michael Kaine"
        @candidates[2] = "Gary Johnson / Bill Weld"
      when /TRUMP/  # Single Space, List full names
        @candidates[1] = "Jill Stein / Ajamu Baraka"
        @candidates[2] = "Donald J Trump / Michael R Pence"
      when /CONLEY/  # Single Space
        @candidates[1] = "Jason Conley"
        @candidates[2] = "Pat Pettey"
      when /MOLLY/ # Spill over to next line
        @candidates[1] = "Molly Baumgardner"
        @candidates[2] = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip.split.map(&:capitalize).join(' ')
      when /AMANDA/ # Spill over to next line
        @candidates[1] = "Amanda Grosserode"
        @candidates[2] = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip.split.map(&:capitalize).join(' ')
      when /STEPHANIE/ # Spill over to next line
        @candidates[1] = "Stepanie Clayton"
        @candidates[2] = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip.split.map(&:capitalize).join(' ')
      when /CHRISTOPHER/ # Spill over to next line
        @candidates[1] = "Christopher McQueeny"
        @candidates[2] = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip.split.map(&:capitalize).join(' ')        
      else
        @candidates[1] = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip.split.map(&:capitalize).join(' ')
        if matches[:rx_candidate_2] && !matches[:rx_candidate_2].empty?
          @candidates[2] = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip.split.map(&:capitalize).join(' ')
        end
    end

    if !@party_affiliation[@candidates[1]]
      $stderr.puts @candidates[1]
      raise(@candidates[1])
    end
    if @candidates[2] && !@candidates[2].empty?
      if !@party_affiliation[@candidates[2]]
        $stderr.puts @candidates[2]
        @party_affiliation[@candidates[2]]
      end
    end
  end

  # method useful to export pdf to csv
  def convert_to_csv(path)
    # When pulling from github, get: PDF does not contain EOF marker
    # io = open('https://github.com/openelections/openelections-sources-ks/blob/master/Johnson/2016%20Johnson%2C%20KS%20precinct-level%20election%20results.pdf')
    #pdf_reader = PDF::Reader.new(io)
    #path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "openelections-sources-ks", "Johnson", "2016\ Johnson\,\ KS\ precinct-level\ election\ results.pdf"))
    #path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "openelections-sources-ks", "Johnson", "2016_Johnson.pdf"))

    pdf_reader = PDF::Reader.new(path)
      File.delete("#{@county}.csv")
      CSV.open("#{@county}.csv","wb") do |csv|
        csv << ["county","precinct","office","district","party","candidate","votes"]
        pdf_reader.pages.each do |page|
          @candidates.clear
          page.text.each_line do |line|
            # skip short or garbage lines
            if line.length < 4
              next
            end
             
            # Set the office
            if /PRESIDENT\/VP/ =~ line
              @office = 'President'
              next
            elsif /US SENATOR/ =~ line
              @office = 'U.S. Senate'
              next
            elsif office_match = line.match(/US REP (?<rx_district>\d+)/)
              @office = 'U.S House'
              @district = office_match[:rx_district]
              next
            elsif office_match = line.match(/STATE SEN (?<rx_district>\d+)/)
              #@set_break = true
              @office = 'State Senate'
              @district = office_match[:rx_district]
              next
            elsif office_match = line.match(/STATE REP (?<rx_district>\d+)/)
              @office = 'State House'
              @district = office_match[:rx_district]
              next
            elsif /DISTRICT ATTORNEY/ =~ line
              @set_break = true
              next
            end           

            # for the beginning of the document with cumulative detail
            if @office == ''
              # skip going through line by line until office is set
              next
            end            
            header_regex = /Reg. Voters\s+Total Votes\s+Times\s+Blank\s+Times\s+(?<rx_candidate_1>[a-zA-Z|' '|\)|\(]+)\s{2,}(?<rx_candidate_2>[a-zA-Z|\s|\)|\(]+)\n/
            spill_over_header_regex_1 = /\s{2,}(?<rx_candidate_1>[a-zA-Z|' '|\)|\(]+)\s{2,}Write-In Votes/
            spill_over_header_regex_2 = /\s{2,}(?<rx_candidate_1>[a-zA-Z|' '|\)|\(]+)\s{2,}(?<rx_candidate_2>[a-zA-Z|\s|\)|\(]+)\s{2,}Write-In Votes/
            spill_over_header_regex_only_write_in = /\s{5,}Write-In Votes/

            line_item_regex = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<reg_voters>\d+)\s+(?<total_voters>\d+)\s+(?<blank_votes>\d+)\s+(?<over_voted>\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)/
            line_item_regex_write_in = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<reg_voters>\d+)\s+(?<total_voters>\d+)\s+(?<blank_votes>\d+)\s+(?<over_voted>\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/

            spill_over_line_item_regex_0 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/
            spill_over_line_item_regex_1 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/
            spill_over_line_item_regex_2 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/

            if matches = line.match(header_regex)
              candidate_name_scrub line, matches
            elsif matches = line.match(spill_over_header_regex_2)
              candidate_name_scrub line, matches
            elsif matches = line.match(spill_over_header_regex_1)
              candidate_name_scrub line, matches
            elsif line_match = line.match(line_item_regex)
              csv << [@county,line_match[:precinct],@office,@district,@party_affiliation[@candidates[1]],@candidates[1],line_match[:candidate_1_votes]]
              csv << [@county,line_match[:precinct],@office,@district,@party_affiliation[@candidates[2]],@candidates[2],line_match[:candidate_2_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_2)
              csv << [@county,line_match[:precinct],@office,@district,@party_affiliation[@candidates[1]],@candidates[1],line_match[:candidate_1_votes]]
              csv << [@county,line_match[:precinct],@office,@district,@party_affiliation[@candidates[2]],@candidates[2],line_match[:candidate_2_votes]]
              csv << [@county,line_match[:precinct],@office,@district,"N/A","write in",line_match[:write_in_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_1)
              csv << [@county,line_match[:precinct],@office,@district,@party_affiliation[@candidates[1]],@candidates[1],line_match[:candidate_1_votes]]
              csv << [@county,line_match[:precinct],@office,@district,"N/A","write in",line_match[:write_in_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_0)
              csv << [@county,line_match[:precinct],@office,@district,"N/A","write in",line_match[:write_in_votes]]
            end
          end
          break if @set_break
        end
      end
    end
  end
  end
  