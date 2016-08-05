#!/usr/bin/env ruby

module Moves

#=====================================================================
# Move logic for Draughts 100 International Rules
#=====================================================================

# Remember:
# - The internal respresentation of our board is an array of 52 char
# - Moves are always calculated for white (uppercase letters) at high numbers!!
# - If black is to move, black and white are swapped and the board is rotated.

# Directions: external representation for easy updating.
# Tables give for each square the next square depending on a direction (NE, NW, SE, SW)
NE_ext =
   '   00  00  00  00  00   '  +  # 01 - 05
   ' 01  02  03  04  05     '  +  # 06 - 10
   '   07  08  09  10  00   '  +  # 11 - 15
   ' 11  12  13  14  15     '  +  # 16 - 20
   '   17  18  19  20  00   '  +  # 21 - 25
   ' 21  22  23  24  25     '  +  # 26 - 30
   '   27  28  29  30  00   '  +  # 31 - 35
   ' 31  32  33  34  35     '  +  # 36 - 40
   '   37  38  39  40  00   '  +  # 41 - 45
   ' 41  42  43  44  45     '     # 46 - 50

NW_ext =
   '   00  00  00  00  00   '  +  # 01 - 05
   ' 00  01  02  03  04     '  +  # 06 - 10
   '   06  07  08  09  10   '  +  # 11 - 15
   ' 00  11  12  13  14     '  +  # 16 - 20
   '   16  17  18  19  20   '  +  # 21 - 25
   ' 00  21  22  23  24     '  +  # 26 - 30
   '   26  27  28  29  30   '  +  # 31 - 35
   ' 00  31  32  33  34     '  +  # 36 - 40
   '   36  37  38  39  40   '  +  # 41 - 45
   ' 00  41  42  43  44     '     # 46 - 50

SE_ext =
   '   07  08  09  10  00   '  +  # 01 - 05
   ' 11  12  13  14  15     '  +  # 06 - 10
   '   17  18  19  20  00   '  +  # 11 - 15
   ' 21  22  23  24  25     '  +  # 16 - 20
   '   27  28  29  30  00   '  +  # 21 - 25
   ' 31  32  33  34  35     '  +  # 26 - 30
   '   37  38  39  40  00   '  +  # 31 - 35
   ' 41  42  43  44  45     '  +  # 36 - 40
   '   47  48  49  50  00   '  +  # 41 - 45
   ' 00  00  00  00  00     '     # 46 - 50

SW_ext =
   '   06  07  08  09  10   '  +  # 01 - 05
   ' 00  11  12  13  14     '  +  # 06 - 10
   '   16  17  18  19  20   '  +  # 11 - 15
   ' 00  21  22  23  24     '  +  # 16 - 20
   '   26  27  28  29  30   '  +  # 21 - 25
   ' 00  31  32  33  34     '  +  # 26 - 30
   '   36  37  38  39  40   '  +  # 31 - 35
   ' 00  41  42  43  44     '  +  # 36 - 40
   '   46  47  48  49  50   '  +  # 41 - 45
   ' 00  00  00  00  00     '     # 46 - 50

# Directions: internal representation is an array of square numbers.
# For example, first square from i in direction NE is NE[i]
NE = [0] + NE_ext.split(' ').map{|s| s.to_i} + [0]
NW = [0] + NW_ext.split(' ').map{|s| s.to_i} + [0]
SE = [0] + SE_ext.split(' ').map{|s| s.to_i} + [0]
SW = [0] + SW_ext.split(' ').map{|s| s.to_i} + [0]

def self.diagonal(i, d)
   # Generator for squares from i in direction d
   Enumerator.new do |enum|
     nxt = i
     stop = d[nxt] == 0
     while not(stop)
        nxt = d[nxt]
        stop = d[nxt] == 0
        enum.yield nxt
     end
   end
end

Directions = [NE, SE, SW, NW]

Move = Struct.new(:steps, :takes)      # steps/takes are arrays of numbers

$moveTable = Hash.new(nil)   # dict to remember legal moves of a position for better performance
$MOVETABLE_SIZE = 1000000

def self.bmoves_from_square(board, i)
   # List of moves (non-captures) for square i
   moves = []     # output list
   p = board[i]
   return [] if not p.isupper?    # only moves for player; return empty list

   if p == 'P' then
      Directions.each do |d|
         q = board[d[i]]
         next if q == '0'       # direction empty; try next direction
         if q == '.' and (d[i] == NE[i] or d[i] == NW[i]) then
            # move detected; save and continue
            moves.push Move.new([ i, d[i] ], [])
         end
      end
   end
   if p == 'K' then
      Directions.each do |d|
         take = nil
         diagonal(i, d).each do |j|     # diagonal squares from i in direction d
            q = board[j]
            break if q == '0'         # stay inside the board; stop with this diagonal
            break if q != '.'         # stop this direction if next square not empty
            if q == '.' then
               # move detected; save and continue
               moves.push Move.new([i,j], [])
            end
         end
      end
   end  # Directions
   return moves
end     # bmoves_from_square ======================================

def self.bcaptures_from_square(board, i)
   # List of one-take captures for square i
   captures = []     # output list
   p = board[i]
   return [] if not p.isupper?   # only captures for player; return empty list

   if p == 'P' then
      Directions.each do |d|
         q = board[d[i]]        # first diagonal square
         next if q == '0'       # direction empty; try next direction
         next if q == '.' or q.isupper?

         if q.islower? then
            r = board[ d[d[i]] ]     # second diagonal square
            next if r == '0'         # no second diagonal square; try next direction
            if r == '.' then
               # capture detected; save and continue
               captures.push Move.new([ i, d[d[i]] ], [ d[i] ])
            end
         end
      end
   end
   if p == 'K' then
      Directions.each do |d|
         take = nil
         diagonal(i, d).each do |j|     # diagonal squares from i in direction d
            q = board[j]
            break if q.isupper?         # own piece on this diagonal; stop
            break if q == '0'           # stay inside the board; stop with this diagonal
            if q.islower? and take == nil then
               take = j      # square number of q
               next
            end
            break if q.islower? and take != nil
            if q == '.' and take != nil then
               # capture detected; save and continue
               captures.push Move.new([i,j], [take])
            end
         end
      end
   end  # Directions

   return captures
end     # bcaptures_from_square ======================================

def self.basicMoves(board)
   # Return list of basic moves of board; either captures or normal moves
   # Basic moves are normal moves or one-take captures
   bmoves_of_board, bcaptures_of_board = [], []
   hasCapture = false
   board.each_with_index do | p, i|
      next if not p.isupper?
      bcaptures = bcaptures_from_square(board, i)
      hasCapture = true if bcaptures.size > 0
      if hasCapture then
         bcaptures_of_board = bcaptures_of_board + bcaptures
      else
         bmoves_of_board = bmoves_of_board + bmoves_from_square(board, i)
      end
   end
   if bcaptures_of_board.size > 0 then
      return bcaptures_of_board
   else
      return bmoves_of_board
   end
end   # basicMoves

def self.searchCaptures(board)
   # Capture construction by extending incomplete captures with basic captures
   $captures = []       # result list of captures
   $max_takes = 0       # max number of taken pieces

   def self.boundCaptures(board, capture, depth )
      # Recursive construction of captures.
      # - board: current board during capture construction
      # - capture: incomplete capture used to extend with basic captures
      # - depth: not used
      bcaptures = bcaptures_from_square(board, capture.steps[-1])   # new extends of capture

      completed = true
      bcaptures.each do |bcapture|

         next if bcapture.takes.size == 0                # no capture; nothing to extend
         next if capture.takes.include? bcapture.takes[0]   # do not capture the same piece twice
         n_from = bcapture.steps[0]
         n_to = bcapture.steps[-1]     # last step

         new_board = board.dup   # clone the board and do the capture without taking pieces
         new_board[n_from] = '.'
         new_board[n_to] = board[n_from]

         new_capture = Move.new(capture.steps.dup, capture.takes.dup)  # make copy of capture and extend it
         new_capture.steps.push bcapture.steps[1]
         new_capture.takes.push bcapture.takes[0]

         extended = false
         result = boundCaptures(new_board, new_capture, depth + 1)   # RECURSION
      end

      if completed then
         # Update global variables
         $captures.push capture
         $max_takes = capture.takes.size if capture.takes.size > $max_takes
      end

      return 0
   end  # boundCaptures

   # ============================================================================
   depth = 0
   bmoves = basicMoves(board)
   bmoves.each do |bmove|
      break if bmove.takes.size == 0    # only moves, no captures; nothing to extend
      n_from = bmove.steps[0]
      n_to = bmove.steps[-1]     # last step

      new_board = board.dup      # clone the board and do the capture without taking pieces
      new_board[n_from] = '.'
      new_board[n_to] = board[n_from]
      result = boundCaptures(new_board, bmove, depth)
   end

   ##puts "Max takes: " + $max_takes.to_s
   result = $captures.select do |capture|
      capture.takes.size == $max_takes
   end

   return result
end # searchCaptures

def self.hasCapture(pos)     # PUBLIC
   # Returns true if capture for white found for position else false.
   pos.board.each_with_index do | p, i|
      next if not p.isupper?
      bcaptures = bcaptures_from_square(pos.board, i)
      return true if bcaptures.size > 0
   end
   return false
end   # hasCapture

def self.gen_moves(pos)       # PUBLIC
   # Returns list of all legal moves of a board for player white (capital letters).
   # Move is a named tuple with array of steps and array of takes
   #
   entry = $moveTable[pos.key()]
   return entry if entry != nil

   if hasCapture(pos) then
      legalMoves = searchCaptures(pos.board)
   else
      legalMoves = basicMoves(pos.board)
   end

   $moveTable[pos.key()] = legalMoves
   if $moveTable.size > $MOVETABLE_SIZE then
      clearTable()
      #$moveTable.shift   # removes an arbitrary (key,value) pair
   end

   return legalMoves
end   # gen_moves ============================================

def self.isLegal(pos, move)     # PUBLIC
   # Returns true if move for position is legal else false.
   if gen_moves(pos).include? move then
       ## puts 'Illegal move: #{move}'
       return true
   end
   return false
end   # isLegal

def self.match_move(pos, steps)
   # Match array of steps with a legal move.
   nsteps = steps.map do |k| k.to_i end     # to integer steps

   lmoves = gen_moves(pos)   # legal moves

   if nsteps.size == 2
      lmoves.each do |move|
         if move.steps[0] == nsteps[0] and move.steps[-1] == nsteps[-1] then
            return move
         end
      end
   else
      lmoves.each do |move|
         if Set.new(move.steps) == Set.new(nsteps) then
            return move
         end
      end
   end
   return nil
end   # match_move

def self.clearTable()
   # Clear moveTable
   $moveTable = Hash.new(nil)
end

def self.tableSize()
   puts "moveTable entries: " + $moveTable.size.to_s
end

###############################################################################

def self.main
   puts
   puts "Started #{$0} but nothing to do; try mad100_run.rb "
   puts

end

if $0 == __FILE__
   main
end

end # module Moves
