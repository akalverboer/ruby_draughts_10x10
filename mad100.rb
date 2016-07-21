#!/usr/bin/env ruby

# -*- coding: utf-8 -*-

# =====================================================================================
# MAD100 is a draughts engine for the 100 squares board.
# Inspired by the chess engine "Sunfish" of Thomas Ahle / Denmark.
# Capture rules same as International Draughts for a 10x10 board.
# Numeric representation of squares.
# =====================================================================================

module Main
  # This module implements the class Position, responsible for saving a board, moving a piece
  # and evaluating a position.
  # Includes printing a board and rendering a move.

# The external respresentation of our board is a 100 character string for easy updating.
INITIAL_EXT = 
    '   p   p   p   p   p '    +  #  01 - 05
    ' p   p   p   p   p   '    +  #  06 - 10
    '   p   p   p   p   p '    +  #  11 - 15
    ' p   p   p   p   p   '    +  #  16 - 20
    '   .   .   .   .   . '    +  #  21 - 25
    ' .   .   .   .   .   '    +  #  26 - 30
    '   P   P   P   P   P '    +  #  31 - 35
    ' P   P   P   P   P   '    +  #  36 - 40
    '   P   P   P   P   P '    +  #  41 - 45
    ' P   P   P   P   P   '       #  46 - 50

INITIAL_EXT_TEST = 
    '   .   K   .   .   . '    +  #  01 - 05
    ' .   .   .   .   .   '    +  #  06 - 10
    '   p   .   k   .   . '    +  #  11 - 15
    ' .   .   .   .   p   '    +  #  16 - 20
    '   .   .   .   .   p '    +  #  21 - 25
    ' .   .   .   .   .   '    +  #  26 - 30
    '   .   p   .   .   . '    +  #  31 - 35
    ' .   .   .   .   .   '    +  #  36 - 40
    '   P   .   .   p   . '    +  #  41 - 45
    ' .   .   .   .   .   '       #  46 - 50

INITIAL_EXT_PROBLEM1 = 
    '   .   .   .   .   p '    +  #  01 - 05  P.Lauwen, DP, 4/1977
    ' .   .   p   .   .   '    +  #  06 - 10
    '   .   .   .   .   P '    +  #  11 - 15
    ' .   .   .   P   .   '    +  #  16 - 20
    '   .   .   .   P   . '    +  #  21 - 25
    ' .   .   .   P   p   '    +  #  26 - 30
    '   .   P   .   .   p '    +  #  31 - 35
    ' .   p   .   .   p   '    +  #  36 - 40
    '   P   p   .   .   p '    +  #  41 - 45
    ' .   .   .   P   P   '       #  46 - 50

###############################################################################
# Evaluation tables
###############################################################################

# Piece Score Table (PST, External Representation) for piece (P) and king (K)
# Because of symmetry the PST is only given for white (uppercase letter)
# Material value for one piece is 1000.

pst_ext = {
  'P'=> '    000   000   000   000   000 '    + #  01 - 05   PIECE promotion line
        ' 045   050   055   050   045    '    + #  06 - 10
        '    040   045   050   045   040 '    + #  11 - 15
        ' 035   040   045   040   035    '    + #  16 - 20
        '    025   030   030   025   030 '    + #  21 - 25   Small threshold to prevent to optimistic behaviour
        ' 025   030   035   030   025    '    + #  26 - 30
        '    020   025   030   020   025 '    + #  31 - 35
        ' 020   015   025   020   015    '    + #  36 - 40
        '    010   015   020   010   015 '    + #  41 - 45
        ' 005   010   015   010   005    ',     #  46 - 50 

  'K'=> '    050   050   050   050   050 '    + #  01 - 05 
        ' 050   050   050   050   050    '    + #  06 - 10
        '    050   050   050   050   050 '    + #  11 - 15
        ' 050   050   050   050   050    '    + #  16 - 20
        '    050   050   050   050   050 '    + #  21 - 25
        ' 050   050   050   050   050    '    + #  26 - 30
        '    050   050   050   050   050 '    + #  31 - 35
        ' 050   050   050   050   050    '    + #  36 - 40
        '    050   050   050   050   050 '    + #  41 - 45
        ' 050   050   050   050   050    '      #  46 - 50
}

# Internal representation of PST with zeros at begin and end (rotation-symmetry)
PST = {'P' => [], 'K' => []}
PST['P'] = [0] + pst_ext['P'].split(' ').map{|s| s.to_i} + [0]
PST['K'] = [0] + pst_ext['K'].split(' ').map{|s| s.to_i} + [0]

PMAT = {'P' => 1000, 'K' => 3000}   # piece material values

###############################################################################
# Draughts logic
###############################################################################

class Position
    # A state of a draughts100 game
    # - board: an array of 52 char; first and last index unused ('0') rotation-symmetry
    # - score: the board evaluation
    # 
    attr_reader :board
    attr_accessor :score

    def initialize(board, score)
       @board = board
       @score = score
    end

    def key()
        return @board.join.to_sym    # array to symbol (hash key)
    end

    def rotate()
        rotBoard = board.reverse.map { |p| p.swapcase }   # clone!
        return Position.new(rotBoard, -@score)
    end

    def clone()
        return Position.new(@board, @score)
    end

    def domove(move)
        # Move is named tuple with list of steps and list of takes
        # Returns new rotated position object after moving.
        # Calculates the score of the returned position.
        # Remember: move is always done with white
        if move == nil then
           return self.rotate()     # turn to other player
        end

        board = @board.dup    # clone board

        # Actual move
        i, j = move.steps[0], move.steps[-1]    # first, last (NB. sometimes i==j !)
        p =  board[i]

        # Move piece and promote to white king
        promotion_line = (1..5)
        board[i] = '.'
        if (promotion_line.include? j) and (p != 'K') then
           board[j] = 'K'
        else
           board[j] = p
        end

        # Capture
        move.takes.each  do  |k|  board[k] = '.'  end

        # We increment the score of the new position depending on the move.
        score = @score + self.eval_move(move) 

        # The incremental update of the score depending on the move is not always
        # possible for evaluation measures like mobility, patterns, etc.
        # If needed we can re-compute the score of the whole position by:
        #      posnew.score = posnew.eval_pos() 
        # The incremental update depending on the move is much faster.

        # We rotate the returned position, so it's ready for the next player
        posnew = Position.new(board, score).rotate()

        return posnew
    end    # domove

    def eval_move(move)
        # Returns increment of board score by this move (neg or pos)
        # Simulate the move and compute increment of the score
        i, j = move.steps[0], move.steps[-1]
        p =  @board[i]

        # Actual move: increment of score by move
        promotion_line = (1..5)
        if (promotion_line.include? j) and (p != 'K') then
           from_val = PST[p][i] + PMAT[p]
           to_val = PST['K'][j] + PMAT['K']    # piece promoted to king
           score = to_val - from_val
        else
           from_val = PST[p][i] + PMAT[p]
           to_val = PST[p][j] + PMAT[p]
           score = to_val - from_val
        end

        # Increase of score because of captured pieces
        move.takes.each do |k|
           q = @board[k].upcase
           score += PST[q][51-k] + PMAT[q]   # score from perspective of other player
        end

        return score
    end    # eval_move

    def eval_pos
       # Computes the board score and returns it
       score1 = 0
       board.each_with_index do | p, i|
          if p.isupper?       # p == 'P' or p == 'K' 
             score1 = score1 + PMAT[p] + PST[p][i]
          end
       end

       rotBoard = board.reverse.map { |p| p.swapcase }  # we want score of opponent
       score2 = 0
       rotBoard.each_with_index do | p, i|
          if p.isupper?       # p == 'P' or p == 'K' 
             score2 = score2 + PMAT[p] + PST[p][i]
          end
       end

       score = score1 - score2
       ##puts('Total score: ', score, score1, score2)
       return score

    end

end # Position

###############################################################################
# User interface
###############################################################################

def self.parse_move(move)
    # Parameter move in numeric format like 32-28 or 26x37.
    # Return array of steps of move/capture in number format.
    nsteps = move.split(/[-x]/).map do |k| k.to_i end
    return nsteps
end

def self.render_move(move)
    # Render move in numeric format
    d = (move.takes.size == 0) ? '-' : 'x'
    return move.steps[0].to_s + d + move.steps[-1].to_s
end

def self.newPos(iBoard)
    # Return position object based on board as string
    board = boardToList(iBoard)   # list of char
    pos = Position.new(board, 0)
    pos.score = pos.eval_pos()
    return pos
end

def self.boardToList(str)
    # Convert board as string to board as list
    board = '0' + str.delete(' ') + '0'
    return board.each_char.to_a
end

def self.print_pos(pos)
    # ⛀    ⛁    ⛂    ⛃
    # board is array 0..52; filled with 'p', 'P', 'k', 'K', '.'
    puts
    spaces = 0
    uni_pieces = {'p' => '⛂', 'k' => '⛃', 'P' => '⛀', 'K' => '⛁', '.' => '·', ' ' => ' '}
    nrows = 10
    row_len = 5   # nrows.div 2
    for i in 1..nrows
       start = (i-1) * row_len + 1
       row = pos.board[start..start + row_len - 1]
       spaces = (spaces == 2) ? 0 : 2    # alternating
       mapped = row.map do |e| uni_pieces[e] end 
       s_from = start.to_s.rjust(2,'0')
       s_to = (start + row_len - 1).to_s.rjust(2,'0')
       puts " #{s_from} - #{s_to}   " + " "*spaces + mapped.join("   ")
    end
    puts
end

######################################################################################
def self.main
   puts
   puts "Started #{$0} but nothing to do; try mad100_run.rb "
   puts
end

if $0 == __FILE__
   main
end

end  # module Main

