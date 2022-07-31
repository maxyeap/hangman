require "yaml"
require "json"
require 'uri'
require 'net/http'

class Game 
  attr_reader :current_player_id

  def initialize
    @players = [HumanPlayer.new, ComputerPlayer.new]
    @correct_word = generate_random_word
    @current_player_id = 0
    @players[0].update_correct_guess(Array.new(@correct_word.length, '_'))
    @players[1].update_correct_guess(Array.new(@correct_word.length, '_'))
    @loader_saver = SaveGame.new(self)
  end

  def current_player
    @players[current_player_id]
  end

  def switch_player!
    @current_player_id = other_player_id
  end

  def other_player_id
    1 - current_player_id
  end

  def generate_random_word
    words_list = File.readlines('google-10000-english-no-swears.txt')
    remove_newline = words_list.map { |word| word.delete "\n" }
    filtered_list = remove_newline.map { |word| word if word.length.between?(5, 12) }
    compact_filtered_list = filtered_list.compact
    p compact_filtered_list[rand(0..compact_filtered_list.length)]
  end

  def update_correct_guess_with_index(letter, index)
    array = current_player.correct_guess
    array[index] = letter
    current_player.update_correct_guess(array)
    puts 'You selection is correct!'
  end

  def start_game
    puts 'Do you want to load the latest save file?'
    answer = gets.chomp.downcase
    return play unless answer == 'yes'

    puts 'Enjoy your game!'
    @loader_saver.load_game.play
  end

  def play
    @loader_saver.get_definition(@correct_word)
    loop do
      guess_update
      player_input = current_player.input_guess
      check_guess(player_input)
      if player_has_won?
        return puts "#{current_player} has won! The correct word is #{@correct_word}."
      elsif balloons_empty?
        switch_player!
        return puts "#{current_player} has won! The correct word is #{@correct_word}."
      end
      guess_update
      switch_player!
      return unless @loader_saver.save_file? == false
    end
  end

  def guess_update
    puts "#{current_player.name.upcase}:"
    puts "Current Correct Guess: #{current_player.correct_guess}"
    puts "Current Incorrect Guess: #{current_player.incorrect_guess}"
  end

  def balloons_empty?
    current_player.numbers_of_balloons.zero?
  end

  def player_has_won?
    current_player.correct_guess.count('_').zero?
  end

  def check_guess(input)
    if correct_word_array.include?(input)
      return punishment(input) unless duplicate?(input) == false

      update_guess(input)
    else
      punishment(input)
    end
  end

  def punishment(input)
    current_player.update_incorrect_guess(input)
    current_player.pop_balloon
  end

  def update_guess(letter)
    array = correct_word_array
    loop do
      index_of_correct_letter = array.find_index(letter)
      if current_player.correct_guess[index_of_correct_letter] == '_'
        update_correct_guess_with_index(letter, index_of_correct_letter)
        return
      else
        array[index_of_correct_letter] = '_'
      end
    end
  end

  def correct_word_array
    @correct_word.split('')
  end

  def duplicate?(input)
    correct_word_array.count(input) == current_player.correct_guess.count(input)
  end
end

class SaveGame
  def initialize(game)
    @game = game
  end

  def save_file?
    puts 'Do you want to save?'
    answer = gets.chomp.downcase
    if answer == 'yes'
      serialized_object = YAML.dump(@game)
      save_file = File.new('save.yml', 'w')
      save_file.puts(serialized_object)
      save_file.close
      puts 'Have a nice day!'
      true
    else
      false
    end
  end

  def load_game
    save_file = File.open('save.yml')
    file_data = save_file.read
    YAML.load(file_data)
  end

  def get_definition(letter)
    app_id = "987e3216"
    app_key = "15530adf55d73218b45eea60cafea97a"
    endpoint = "entries"
    language_code = "en-us"
    word_id = letter
    url = URI("https://od-api.oxforddictionaries.com/api/v2/" + endpoint + "/" + language_code + "/" + word_id.downcase)
    r = Net::HTTP.get_response(url, {"app_id": app_id, "app_key": app_key})
    data = JSON.parse r.body.gsub('=>', ':')
    begin
      puts "CLUE: #{data['results'][0]['lexicalEntries'][0]['entries'][0]['senses'][0]['definitions'][0]}"
    rescue
      puts 'No definition for this one. Good Luck!'
    end
    
  end
end

class Player
  def initialize
    @numbers_of_balloons = 5
    @correct_guess = []
    @incorrect_guess = []
  end

  def pop_balloon
    @numbers_of_balloons -= 1
    puts "Wrong! #{@name}, you have #{@numbers_of_balloons} balloons left."
  end

  def update_correct_guess(array)
    @correct_guess = array
  end

  def update_incorrect_guess(input)
    @incorrect_guess.push(input)
  end
end

class HumanPlayer < Player
  attr_reader :correct_guess, :numbers_of_balloons, :incorrect_guess, :name

  def initialize
    super
    @name = 'Human'
  end

  def input_guess
    puts 'Human, please input your guess'
    input = gets.chomp.downcase
    return input unless input.length != 1 || input.match?(/[[:alpha:]]/) == false

    puts 'Input is not valid. Please try again.'
    input_guess
  end
end

class ComputerPlayer < Player
  attr_reader :correct_guess, :numbers_of_balloons, :incorrect_guess, :name

  def initialize
    super
    @name = 'Computer'
  end

  def input_guess
    c_guess = ('a'..'z').to_a.sample
    loop do
      c_guess = ('a'..'z').to_a.sample
      break if @incorrect_guess.include?(c_guess) == false
    end
    puts "Computer guess is #{c_guess}"
    c_guess
  end
end

Game.new.start_game
