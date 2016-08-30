require 'csv'
require 'uri'

# Form:
# name (e.g. JW1950_ECK1963)
# unique_code (optional unique code, e.g. SBCR3562525 A1)
# origin ("comment", e.g. HTML table)
# org (numeric database ID (ecoli is 1, yeast is 2))
# org2 (related to organism)
# genotype (e.g. setC)
# keeper (owner, numeric database ID (sandra is 2))
# box_select (numeric database ID of box, e.g. 151)
# box_details (position in box e.g. D7)

# CSV row:
# Plate,Row,Col,JW_id,Strain,Comment,ECK number,Escherichia coli MG1655 B id,gene name,Clone Catalog Number,Fluidx position
# 1,A,1,JW1950,1,ready to distribute,ECK1963,b1967,hchA,OEC4987-200827314,50030761
# {
#     'Plate' => '2',
#     'Row' => 'A',
#     'Col' => '1',
#     'JW_id' => 'JW1950',
#     'Strain' => '2',
#     'Comment' => 'ready to distribute',
#     'ECK number' => 'ECK1963',
#     'Escherichia coli MG1655 B id' => 'b1967',
#     'gene name' => 'hchA',
#     'Clone Catalog Number' => 'OEC4987-213603667',
#     'Fluidx position' => nil
# }

# Plate number -> Database ID of old -80C storage box
PLATE_TO_BOX_ID_MAP = {
                1 => 543,  2 => 555,  3 => 556,  4 => 557,  5 => 558,  6 => 559,  7 => 560,  8 => 561,  9 => 562,
    10 => 563, 11 => 564, 12 => 565, 13 => 566, 14 => 567, 15 => 568, 16 => 569, 17 => 570, 18 => 571, 19 => 606,
    20 => 672, 21 => 673, 22 => 674, 23 => 675, 24 => 676, 25 => 677, 26 => 678, 27 => 679, 28 => 680, 29 => 681,
    30 => 682, 31 => 683, 32 => 684, 33 => 685, 34 => 686, 35 => 687, 36 => 688, 37 => 689, 38 => 690, 39 => 691,
    40 => 692, 41 => 693, 42 => 694, 43 => 695, 44 => 696, 45 => 697, 46 => 699, 47 => 698, 48 => 700, 49 => 701,
    50 => 702, 51 => 703, 52 => 704, 53 => 706, 54 => 705, 55 => 707, 56 => 708, 57 => 709, 58 => 710, 59 => 711,
    60 => 712, 61 => 713, 62 => 714, 63 => 715, 64 => 716, 65 => 717, 66 => 718, 67 => 719, 68 => 720, 69 => 721,
    70 => 722, 71 => 723, 72 => 724, 73 => 725, 74 => 726, 75 => 727, 76 => 728, 77 => 729, 78 => 730, 79 => 731,
    80 => 732, 81 => 733, 82 => 734, 83 => 735, 84 => 736, 85 => 737, 86 => 738, 87 => 739, 88 => 740, 89 => 741,
    90 => 742
}

HTML_TABLE = %(
&lt;table border="0" cellpadding="0" cellspacing="0" style="width:909px;" width="908"&gt;
  &lt;colgroup&gt;
    &lt;col span="5" /&gt;
    &lt;col /&gt;
    &lt;col /&gt;
    &lt;col /&gt;
    &lt;col /&gt;
    &lt;col /&gt;
    &lt;col /&gt;
  &lt;/colgroup&gt;
  &lt;tbody&gt;
    &lt;tr height="36"&gt;
      &lt;td height="36" style="height:36px;width:64px;"&gt;Plate&lt;/td&gt;
      &lt;td style="width:64px;"&gt;Row&lt;/td&gt;
      &lt;td style="width:64px;"&gt;Col&lt;/td&gt;
      &lt;td style="width:64px;"&gt;JW_id&lt;/td&gt;
      &lt;td style="width:64px;"&gt;Strain&lt;/td&gt;
      &lt;td style="width:128px;"&gt;Comment&lt;/td&gt;
      &lt;td style="width:64px;"&gt;ECK number&lt;/td&gt;
      &lt;td style="width:108px;"&gt;Escherichia coli MG1655 B id&lt;/td&gt;
      &lt;td style="width:97px;"&gt;gene name&lt;/td&gt;
      &lt;td style="width:115px;"&gt;Clone Catalog Number&lt;/td&gt;
      &lt;td style="width:77px;"&gt;Fluidx position&lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr height="21"&gt;
      &lt;td height="21" style="height:21px;"&gt;%{Plate}&lt;/td&gt;
      &lt;td&gt;%{Row}&lt;/td&gt;
      &lt;td&gt;%{Col}&lt;/td&gt;
      &lt;td&gt;%{JW_id}&lt;/td&gt;
      &lt;td&gt;%{Strain}&lt;/td&gt;
      &lt;td&gt;%{Comment}&lt;/td&gt;
      &lt;td&gt;%{ECK number}&lt;/td&gt;
      &lt;td&gt;%{Escherichia coli MG1655 B id}&lt;/td&gt;
      &lt;td&gt;%{gene name}&lt;/td&gt;
      &lt;td&gt;%{Clone Catalog Number}&lt;/td&gt;
      &lt;td&gt;%{Fluidx position}&lt;/td&gt;
    &lt;/tr&gt;
  &lt;/tbody&gt;
&lt;/table&gt;
)

TEXT_COMMENT = %(
      Plate: %{Plate},
      Row: %{Row},
      Col: %{Col},
      JW_id: %{JW_id},
      Strain: %{Strain},
      Comment: %{Comment},
      ECK number: %{ECK number},
      Escherichia coli MG1655 B id: %{Escherichia coli MG1655 B id},
      gene name: %{gene name},
      Clone Catalog Number: %{Clone Catalog Number},
      Fluidx position: %{Fluidx position}
)


def keys_to_sym(hash)
  hash.keys.each do |key|
    hash[(key.to_sym rescue key) || key] = hash.delete(key)
  end
end

def build_comment(row)
  hash = row.to_hash
  keys_to_sym(hash)

  TEXT_COMMENT % hash
end

def build_list(csv_file_name)
  list = []
  index = 0

  CSV.foreach(csv_file_name, headers: true) do |row|
    index += 1
    form = {}
    begin
      form['name'] = "#{row['Clone Catalog Number']}"
#     form['unique_code'] = "#{index.to_s.rjust(5,'0')}"
      form['origin'] = build_comment(row)
      form['genotype'] = row['gene name']
      form['box_select'] = PLATE_TO_BOX_ID_MAP.fetch(row['Plate'].to_i)
      form['box_details'] = "#{row['Row']}#{row['Col']}," # Trailing comma is required!
      form['org'] = '1' # e-coli
      form['org2'] = '1' # e-coli
      form['keeper'] = '2' # Sandra

      list << form
    rescue Exception => e
      puts "Row #{index}"
      puts row.inspect
      raise e
    end
  end

  list
end

def register(item)
  data = URI.encode_www_form(item)
  id = `curl -X POST -H "X-LC-APP-Charset: UTF-8" -H "X-LC-APP-Auth: #{ARGV[0]}" -H "Accept: application/json" --data "#{data}" http://agilebio.com/clients/synbiochem/webservice/v1/strains/`
  puts id
  id
end

if ARGV.length < 2
  puts "usage: ruby keio_bulk_upload.rb <API key> <path to CSV file>"
else
  puts "Reading CSV..."
  list = build_list(ARGV[1]);''

  puts "Registering strains..."
  ids = []
  list.each do |item|
    ids << register(item)
  end

  puts "Registered IDs:"
  puts ids.inspect
  puts
  puts "Done."
end
