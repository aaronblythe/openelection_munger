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
    
   party_affiliation = {
     "CLINTON AND KAINE": "Democrat",
     "JOHNSON AND WELD": "Libertarian",
     "STEIN AND BARAKA": "Green",
     "TRUMP AND PENCE": "Republican",
     "Write-in": "N/A",
     "JERRY MORAN": "Republican",
     "ROBERT D GARRARD": "Libertarian",
     "PATRICK WIESNER": "Democrat",
     "STEVEN A HOHE": "Libertarian",
     "JAY SIDIE": "Democrat",
     "KEVIN YODER": "Republican"
   }

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
              office = "PRESIDENT/VP"
              next
            elsif /US SENATOR/=~line
              office = "US SENATOR"
              next
            elsif /US REP 3/=~line
              office = "US REP"
              district = "3"
              next
            elsif /STATE SEN 6/=~line
              # end.  The rest is state level
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
            spill_over_line_item_regex_1 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/
            spill_over_line_item_regex_2 = /\s+(?<precinct>[a-zA-Z|' ']+\d-\d+)\s+(?<candidate_1_votes>\d+)\s+(?<candidate_1_percent>\d+.\d+%)\s+(?<candidate_2_votes>\d+)\s+(?<candidate_2_percent>\d+.\d+%)\s+(?<write_in_votes>\d+)\s+(?<write_in_percent>\d+.\d+%)/

            if matches = line.match(header_regex)
              candidate_1 = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip
              candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
            elsif matches = line.match(spill_over_header_regex_2)
              if special_case = line.match(/TRUMP/)
                candidate_1 = "STEIN AND BARAKA"
                candidate_2 = "TRUMP AND PENCE" 
              else
                candidate_1 = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip
                candidate_2 = matches[:rx_candidate_2].sub(/\(.\)/, '').rstrip
              end
            elsif matches = line.match(spill_over_header_regex_1)
              candidate_1 = matches[:rx_candidate_1].sub(/\(.\)/, '').rstrip
            elsif line_match = line.match(line_item_regex)
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_1.to_sym],candidate_1,line_match[:candidate_1_votes]]
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_2.to_sym],candidate_2,line_match[:candidate_2_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_2)
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_1.to_sym],candidate_1,line_match[:candidate_1_votes]]
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_2.to_sym],candidate_2,line_match[:candidate_2_votes]]
              csv << [county,line_match[:precinct],office,district,"N/A","write in",line_match[:write_in_votes]]
            elsif line_match = line.match(spill_over_line_item_regex_1)
              csv << [county,line_match[:precinct],office,district,party_affiliation[candidate_1.to_sym],candidate_1,line_match[:candidate_1_votes]]
              csv << [county,line_match[:precinct],office,district,"N/A","write in",line_match[:write_in_votes]]
            end
          end
          if set_break
            break
          end
        end
      end
    end
  end
  end
  