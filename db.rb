require 'net/http'
require 'open-uri'

def initialize_db_module
  if !$dont_use_marshalp
    $SERIALIZER = Marshal
    $DATA_PATH = 'marshalp'
    return
  end

  begin
    require 'json'
    $SERIALIZER = JSON
    $DATA_PATH = 'jsonp'
  rescue LoadError
    STDERR.puts 'No json module installed. We\'ll use YAML, but please consider installing json module as there are known bugs in YAML loader.'
    require 'yaml'
    $SERIALIZER = YAML
    $DATA_PATH = 'yamlp'
  end
end

def golf_file(f)
  File.join(GOLF_DIR, f)
end

def ag_file(f)
  File.join(AG_DIR, f)
end

def db_ag(f)
  Marshal.load(File.read(ag_file(f)))
end

def ag_escape(url)
  url.gsub(' ', '+')
end

def ag_escape(url)
  url.gsub(' ', '+')
end

def ag_unescape(url)
  url.gsub('+', ' ')
end

def download_ag(http, f)
  initialize_db_module
  url = ag_escape("/#{$DATA_PATH}.rb?#{f[/[^.]+/]}")
  puts "Downloading #{f}..."
  File.open(ag_file(f), 'w') do |ofile|
    o = $SERIALIZER.load(http.get(url).read_body)
    ofile.print Marshal.dump(o)
  end
end

def update_ag_db(http, f)
  if !File.exist?(ag_file(f))
    download_ag(http, f)
  end
end

def update_ag
  http = Net::HTTP::new('golf.shinh.org', 80)
  download_ag(http, 'problem.db')
  ag_problems.each do |f|
    update_ag_db(http, f + '.db')
  end
end

def spoj_file(f)
  File.join(SPOJ_DIR, f)
end

def update_spoj
  puts 'Downloading the list of problems...'
  c = open('http://www.spoj.pl/SHORTEN/ranks/', &:read)
  File.open(spoj_file('ranks.html'), 'w') do |of|
    of.print(c)
  end
  c.scan(/<a href='\/SHORTEN\/problems\/(.*?)'>/) do
    probname = $1
    filename = spoj_file(probname)
    if File.exists?(filename + '.html')
      next
    end

    puts "Downloading the #{probname}.html..."
    spec = open("http://www.spoj.pl/SHORTEN/problems/#{probname}/", &:read)
    File.open(filename + '.html', 'w') do |of|
      of.print(spec)
    end

    spec.gsub!(/<br\s*\/>/, "\n")
    if spec =~ /<pre>[\s\n]*<strong>Input:<\/strong>(.*?)<strong>Output:<\/strong>(.*?)<\/pre>/ms
      input = $1.strip
      output = $2.strip
      File.open(filename + '.test', 'w') do |of|
        of.puts(input + "\n\n__INPUT__\n" + output + "\n\n__OUTPUT__")
      end
    else
      puts "Example I/O not found"
    end
  end
end

def golf_db_file
  golf_file('golf.db')
end

def ag_problems
  db_ag('problem.db')['root']
end

def get_user
  golf_db = get_golf_db
  golf_db.transaction do
    golf_db['user'].rstrip
  end
end

def get_golf_db
  PStore.new(golf_db_file)
end

def update_file2problem(basename, problem)
  golf_db = get_golf_db
  golf_db.transaction do
    golf_db['file2problem'][basename] = problem
  end
end

def file2problem(basename, guess_ag = true)
  golf_db = get_golf_db
  golf_db.transaction(true) do
    problem = golf_db['file2problem'][basename]
    return problem if problem
  end

  return nil if !guess_ag

  eds = []
  ag_problems.each do |problem|
    eds << [similarity(problem, basename), problem]
  end
  eds.sort!
  #ed, problem = eds[0]
  #print "#{basename} corresponds to #{problem}? (edit distance #{ed}) (Y/n): "
  puts "#{basename} corresponds to"
  puts " #{i=0}: none of below"
  eds[0,5].each do |ed, problem|
    puts " #{i+=1}: #{problem} (#{ed})"
  end
  print "Input 0-5 [1] ? : "
  num = STDIN.gets
  if num =~ /^$/
    num = 1
  else
    num = num.to_i
  end
  if num > 0
    problem = eds[num-1][1]
    problem = "http://golf.shinh.org/p.rb?#{ag_escape(problem)}"
  else
    print "Please input problem URL for #{basename}: "
    problem = STDIN.gets
    if problem =~ /^$/
      raise "Couldn't obtain problem name"
    end
  end

  update_file2problem(basename, problem)

  problem
end
