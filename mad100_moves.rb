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

# Allowed directions for piece and king
Directions = {
    'P' => [NE, SE, SW, NW],    # piece can move forward but captures in all directions
    'K' => [NE, SE, SW, NW]     # king can move in all directions
}

Move = Struct.new(:steps, :takes)      # steps/takes are arrays of numbers 

def self.gen_bmoves(board, i)    # PRIVATE ============================
   # Generator for moves or one-take captures for square i
   # If test == true: output is boolean (capture detected or not)
   moves, captures = [], []     # output lists
   p = board[i]
   return [[].each, :empty] if not p.isupper?     # only moves for player; return empty generator
   Directions[p].each do |d|
      if p == 'P' then
         q = board[d[i]]
         next if q == '0'       # direction empty; try next direction
         if q == '.' and (d[i] == NE[i] or d[i] == NW[i]) then
            # move detected; save and continue
            moves.push Move.new([ i, d[i] ], [])
         end
         if q.islower? then
            r = board[ d[d[i]] ]     # second diagonal square
            next if r == '0'     # no second diagonal square; try next direction
            if r == '.' then
               # capture detected; save and continue
               captures.push Move.new([ i, d[d[i]] ], [ d[i] ])
            end
         end
      end
      if p == 'K' then
         take = nil
         diagonal(i, d).each do |j|     # diagonal squares from i in direction d
            q = board[j]
            break if q.isupper?       # own piece on this diagonal; stop
            break if q == '0'         # stay inside the board; stop with this diagonal
            if q == '.' and take == nil then
               # move detected; save and continue
               moves.push Move.new([i,j], [])
            end
            if q.islower? and take == nil then
               take = j      # square of q
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

   # Prepare output. Output is tuple: [generator, type]
   # - generator of basic moves
   # - type symbol: :capture, :move, :empty
   if captures != [] then           # first try captures !!
      [captures.each, :capture]
   elsif moves != [] then 
      [moves.each, :move]
   else
      [[].each, :empty]     # empty generator
   end
end     # gen_bmoves ======================================

def self.gen_extend_move(board, move)   # PRIVATE ===================
   # move is capture and maybe incomplete; try to extend it with basic captures
   # return generator of extended captures

   return [].each if move.steps.size == 0   # empty move; return empty generator
   return [].each if move.takes.size == 0   # no capture; return empty generator
   n_from = move.steps[0]
   n_to = move.steps[-1]     # last step

   new_board = board.dup   # clone the board after doing the capture without taking the pieces
   new_board[n_from] = '.'
   new_board[n_to] = board[n_from]


   Enumerator.new do |enum|
      gen_bmoves(new_board, n_to)[0].each do | bmove|
         new_move = Move.new(move.steps.dup, move.takes.dup)  # make copy of move and extend it
         next if bmove.takes == []                      # no capture; nothing to extend
         next if move.takes.include? bmove.takes[0]     # do not capture the same piece
         new_move.steps.push bmove.steps[1]
         new_move.takes.push bmove.takes[0]
         enum.yield new_move
      end
   end

end  # gen_extend_move ============================================

def self.gen_moves_of_square(board, i)   # PRIVATE ====================
   # Make array (generator) with completed moves of square i

   def self.OLD_gen_extend_next_OLD(board, move)
      # Make generator of all moves that can extend given move (only for captures, use recursion)
      # If move is not a capture, return generator of given move parameter
      Enumerator.new do |enum|
         thing_generated = false
         gen_extend_move(board, move).each do |new_move|
            thing_generated = true
            gen_extend_next(board, new_move).each do |val|
               enum.yield val   # val is enumerator
            end
         end
         if not thing_generated then
            ##print 'ready   ', move
            enum.yield move
         end
      end
   end   # old_gen_extend_next_old

   def self.gen_extend_next(board, move)
      # SAME AS ABOVE BUT: enumerator replaced by array moveList.
      # No performance improvement. For clarity we use this version.
      # Make generator of all moves that can extend given move (only for captures, use recursion)
      # If move is not a capture, return generator of given move parameter
      moveList = []
         thing_generated = false
         gen_extend_move(board, move).each do |new_move|
            thing_generated = true
            gen_extend_next(board, new_move).each do |emove|
                moveList.push emove
            end
         end
         if not thing_generated then
            ##print 'ready   ', move
             moveList.push move
         end
      return moveList
   end   # gen_extend_next

   Enumerator.new do |enum|
      gen_bmoves(board, i)[0].each do |bmove|
         # CHANGE: some performance improvement 16-07-2016
         if bmove.takes.size == 0 then
            enum.yield bmove
         else
            # bmove is capture; make move complete 
            gen_extend_next(board, bmove).each do |move|
               enum.yield move
            end
         end
      end
   end

end   # gen_moves_of_square ============================================

def self.gen_moves_of_board(board)  # PRIVATE ============================
   # Generate all possible moves for white; not yet legal moves!! 
   Enumerator.new do |enum|
      board.each_with_index do | p, i|
         next if not p.isupper?       # p == 'P' or p == 'K' 
         gen_moves_of_square(board, i).each do |move|
            enum.yield move
         end
      end
   end
end   # gen_moves_of_board =============================================

def self.gen_moves(pos)       # PUBLIC
   # Returns generator of all legal moves of a board for player white (capital letters).
   # Move is a named tuple with array of steps and array of takes

   moveList = []
   max_takes = 0
   gen_moves_of_board(pos.board).each do |move|
      max_takes = [max_takes, move.takes.size].max
      moveList.push move
   end

   Enumerator.new do |enum|
      moveList.each do |move|
         ##puts 'MAX/MOVE: ', max_takes, move.takes
         if move.takes.size == max_takes then
            enum.yield move
         end
      end
   end
end   # gen_moves ============================================

def self.hasCapture(pos)     # PUBLIC
   # Returns true if capture for white found for position else false.
   pos.board.each_with_index do | p, i|
      next if not p.isupper?       # p == 'P' or p == 'K' 
      type = gen_bmoves(pos.board, i)[1]
      return true if type == :capture    # capture found
   end
   return false
end   # hasCapture 

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

###############################################################################
def self.test1(pos, i)       # PUBLIC
   gen_bmoves(pos.board, i)[0].each do |bmove|
      puts bmove
   end
end

def self.test2(pos)          # PUBLIC
   move = Move.new([2,16], [11])
   gen_extend_move(pos.board, move).each do |emove|
      puts emove
   end
end

def self.test3(pos,i)         # PUBLIC
   gen_moves_of_square(pos.board, i).each do |move|
      puts move
   end
   puts
   gen_moves_of_board(pos.board).each do |move|
      puts move
   end
   puts
   puts 'Legal moves:'
   gen_moves(pos).each do |move|
      puts move
   end
end

#############################################################################################
def self.main
   puts
   puts "Started #{$0} but nothing to do; try mad100_run.rb "
   puts
end

if $0 == __FILE__
   main
end

end # module Moves
