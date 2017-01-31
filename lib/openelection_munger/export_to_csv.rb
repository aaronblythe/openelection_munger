require 'open-uri'
require 'pdf/reader'
require 'pathname'
require 'csv'

module OpenelectionMunger
class ExportToCsv
  # method useful to export pdf to csv
  def convert_to_csv
    county = 'Johnson'
    precinct = '' # from line 
    office = '' # From page heading 
    district = '' # From page heading for Reps
    party = '' # From Column heading
    candidate_1 = '' # From Column heading
    candidate_2 = '' # From Column heading
    votes = '' # From line
    registered_voters = '' # From line
    set_break = false

    begin
      CSV::Converters[:blank_to_nil] = lambda do |field|
        field && field.empty? ? nil : field
      end
      candidates = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "states", "kansas", "candidates.csv"))
      csv = CSV.read(candidates, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
      csv_hash = csv.map {|row| row.to_h }
      party_affiliation = Hash.new
      csv_hash.each do |row|
        candidate = row[:candidate].gsub(/\./, '').rstrip
        party_affiliation[candidate] = row[:party].rstrip
      end
    rescue StandardError => e
      puts "CSV failed (#{e.message})"
    end

    # When pulling from github, get: PDF does not contain EOF marker
    # io = open('https://github.com/openelections/openelections-sources-ks/blob/master/Johnson/2016%20Johnson%2C%20KS%20precinct-level%20election%20results.pdf')
    #pdf_reader = PDF::Reader.new(io)
    #path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "openelections-sources-ks", "Johnson", "2016\ Johnson\,\ KS\ precinct-level\ election\ results.pdf"))
    path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "openelections-sources-ks", "Johnson", "2016_Johnson.pdf"))

    pdf_reader = PDF::Reader.new(path)
      File.delete("#{county}.csv")
      CSV.open("#{county}.csv","wb") do |csv|
        csv << ["county","precinct","office","district","party","candidate","votes"]
        pdf_reader.pages.each do |page|
          page.text.each_line do |line|
            # skip short or garbage lines
            if line.length < 4
              next
            end
             
            # Set the office
            if /PRESIDENT\/VP/=~line
              office = 'President'
              next
            elsif /US SENATOR/=~line
              office = 'U.S. Senate'
              next
            elsif /US REP 3/=~line
              office = 'U.S House'
              district = '3'
              next
            elsif /STATE SEN (?<rx_district>\d+)/=~line
              office = 'State Senate'
              district = rx_district
            elsif /STATE REP (?<rx_district>\d+)/=~line
              office = 'State House'
              district = rx_district
            elsif /DISTRICT ATTORNEY/=~line
              set_break = true
            end           

            # for the beginning of the document with cumulative detail
            if office == ''
              # skip going through line by line until office is set
              next
            end            
            header_regex = /Reg. Voters\s+Total Votes\s+Times\s+Blank\s+Times\s+(?<rx_candidate_1>[a-zA-Z|' '|\)|\(]+)\s{2,}(?<rx_candidate_2>[a-zA-Z|\s|\)|\(]+)\n/
            spill_over_header_regex_1 = /\s{2,}(?<rx_candidate_1>[a-zA-Z|' '|\)|\(]+)\s{2,}Write-In Votes/
            spill_over_header_regex_2 = /\s{2,}(?<rx_candidate_1>[a-zA-Z|' '|\)|\(]+)\s{2,}(?<rx_candidate_2>[a-zA-Z|\s|\)|\(]+)\s{2,}Write-In Votes/
            
            line_item_regex = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<reg_voters>\d+)\s+(?<total_voters>\d+)\s+(?<blank_votes>\d+)\s+(?<over_voted>\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)/
            line_item_regex_write_in = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<reg_voters>\d+)\s+(?<total_voters>\d+)\s+(?<blank_votes>\d+)\s+(?<over_voted>\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/

            spill_over_line_item_regex_0 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/
            spill_over_line_item_regex_1 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/
            spill_over_line_item_regex_2 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/

            if matches = line.match(header_regex)
              if line.match(/CLINTON/)
                candidate_1 = "Hillary Rodham Clinton / Timothy Michael Kaine"
                candidate_2 = "Gary Johnson / Bill Weld"                
              else
                candidate_1 = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
              end
            elsif matches = line.match(spill_over_header_regex_2)
              if line.match(/TRUMP/)
                candidate_1 = "Jill Stein / Ajamu Baraka"
                candidate_2 = "Donald J Trump / Michael R Pence"
              elsif line.match(/MOLLY/) 
                candidate_1 = "MOLLY BAUMGARDNER"
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
              elsif line.match(/AMANDA/)
                candidate_1 = "AMANDA GROSSERODE"
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
              elsif line.match(/STEPHANIE/)
                candidate_1 = "STEPHANIE CLAYTON"
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
              elsif line.match(/CHRISTOPHER/)
                candidate_1 = "CHRISTOPHER MCQUEENY"
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip        
              else
                candidate_1 = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
              end
            elsif matches = line.match(spill_over_header_regex_1)
              candidate_1 = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip
            elsif line_match = line.match(line_item_regex)
              candidate_1 = candidate_1.split.map(&:capitalize).join(' ')
              candidate_2 = candidate_2.split.map(&:capitalize).join(' ')
              raise(candidate_1) unless party_affiliation[candidate_1]
              raise(candidate_2) unless party_affiliation[candidate_2]

              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_1],candidate_1,line_match[:candidate_1_votes]]
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_2],candidate_2,line_match[:candidate_2_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_2)
              candidate_1 = candidate_1.split.map(&:capitalize).join(' ')
              candidate_2 = candidate_2.split.map(&:capitalize).join(' ')
              raise(candidate_1) unless party_affiliation[candidate_1]
              raise(candidate_2) unless party_affiliation[candidate_2]
              
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_1],candidate_1,line_match[:candidate_1_votes]]
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_2],candidate_2,line_match[:candidate_2_votes]]
              csv << [county,line_match[:precinct],office,district,"N/A","write in",line_match[:write_in_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_1)
              candidate_1 = candidate_1.split.map(&:capitalize).join(' ')
              raise(candidate_1) unless party_affiliation[candidate_1]

              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_1],candidate_1,line_match[:candidate_1_votes]]
              csv << [county,line_match[:precinct],office,district,"N/A","write in",line_match[:write_in_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_0)
              csv << [county,line_match[:precinct],office,district,"N/A","write in",line_match[:write_in_votes]]
            end
          end
          break if set_break
        end
      end
    end
  end
  end
  