#!/usr/bin/env ruby

# -*- coding: utf-8 -*-

module Play
   ##puts 'module Play initialized'

#=====================================================================
# Module methods for playing a game
#=====================================================================

# FEN examples
FEN_INITIAL = "W:B1-20:W31-50"
FEN_MAD100_1 = "W:W15,19,24,29,32,41,49,50:B5,8,30,35,37,40,42,45.Lauwen1977"  # P.Lauwen, DP, 4/1977
FEN_MAD100_2 = "W:W17,28,32,33,38,41,43:B10,18-20,23,24,37."
FEN_MAD100_3 = "W:WK3,25,34,45:B38,K47."
FEN_MAD100_4 = "W:W18,23,31,33,34,39,47:B8,11,20,24,25,26,32.xxx"       # M.Dalman
FEN_MAD100_5 = "B:B7,11,13,17,20,22,24,30,41:W26,28,29,31,32,33,38,40,48."  # after 30-35 white wins

Entry_pv = Struct.new(:pos, :score, :move)    # Entry for saving principal variation moves

def self.parseFEN(iFen) 
   # Parses a string in Forsyth-Edwards Notation into a Position
   fen = iFen                  # working copy
   fen = fen.delete(" ")       # remove all whitespace
   fen = fen.sub(/\..*$/, '')  # cut off info (.xxx) at the end

   fen = 'W:B:W' if fen == ''      # empty FEN Position
   fen = 'W:B:W' if fen == 'W::' 
   fen = 'B:B:W' if fen == 'B::' 
   fen = fen.sub(/.?::$/, 'W:W:B')
   parts = fen.split(':')

   rlist = ['0']*51           # init temp return array
   sideToMove = parts[0][0] == 'B' ? 'B' : 'W'
   rlist[0] = sideToMove

   for i in 1..2         # process the two sides
      side = parts[i]                # working copy
      color = side[0]                # first char
      side = side[1..-1]             # strip first color char
      next if side.size == 0         # nothing to do: next side
      numSquares = side.split(',')   # list of numbers or range of numbers with/without king flag

      numSquares.each do |num|
         isKing = (num[0] == 'K') ? true : false
         num = num[1..-1] if isKing       # strip 'K'

         isRange = (num.split('-').size == 2) ? true : false
         if isRange then
            r = num.split('-')
            for j in ( r[0].to_i .. r[1].to_i )
               rlist[j] = isKing ? color.upcase : color.downcase
            end
         else
            rlist[num.to_i] = isKing ? color.upcase : color.downcase
         end
      end
   end  # for

   # prepare output
   pcode = {'w' => 'P', 'W' => 'K', 'b' => 'p', 'B' => 'k', '0' => '.'}
   board = ['0'] + rlist[1..-1].map do |elem| pcode[elem] end  + ['0']


   pos = Main::Position.new(board, 0)   # module 'mad100'
   pos.score = pos.eval_pos
   return ( sideToMove == 'W' ? pos : pos.rotate )

end   # parseFEN

def self.mrender_move(color, move)
    # Render move in numeric format: (m)utual version
    return '' if move == nil

    steps = color == Run::WHITE ? move.steps : move.steps.map do |i| 51-i end 
    takes = color == Run::WHITE ? move.takes : move.takes.map do |i| 51-i end 
    rmove = Moves::Move.new(steps, takes)      # module Moves
    return Main.render_move(rmove)           # module 'mad100'
end

def self.mparse_move(color, move)
    # Parameter move in numeric format like 17-14 or 10x17.
    # Return list of steps of move/capture in number format depending on color.
    nsteps = Main.parse_move(move)     # module 'mad100'
    return ( color == Run::WHITE ? nsteps : nsteps.map do |i| 51 - i end )
end

def self.mprint_pos(color, pos)
    # Print position depending on color
    if color == Run::WHITE then
       Main.print_pos(pos)           # module 'mad100'
    else
       Main.print_pos(pos.rotate())  # module 'mad100'
    end
    puts ['white', 'black'][color] + ' to move '
end

def self.gen_pv(pos, tp) 
    # Returns generator of principal variation list of scores and moves from transposition table
    poskeys = Set.new()   # used to prevent loop
    postemp = pos.clone() 
    Enumerator.new do |enum|
       while true
          entry = tp[postemp.key()]  # get entry of transposition table
          if poskeys.include? postemp.key() then
             break    # Loop
          end
          if entry == nil then
             break
          end
          if entry.move == nil then
             enum.yield Entry_pv.new(postemp, entry.score, entry.move)
             break
           end

           enum.yield Entry_pv.new(postemp, entry.score, entry.move)
           poskeys.add(postemp.key())
           postemp = postemp.domove(entry.move)
       end
    end
end

def self.render_pv(origc, pos, tp) 
    # Returns principal variation string of scores and moves from transposition table tp
    res = []
    color = origc
    res.push '|'
    entry = Entry_pv.new(nil, nil, nil)  # default
    last_score = 0
    gen_pv(pos, tp).each do |entry|
       if entry.move == nil then
          res.push 'null'
       else
          move = mrender_move(color, entry.move)
          res.push move
          last_score = entry.score
       end

       res.push '|'
       color = 1-color
    end

    res.push " final score: "
    res.push last_score.to_s

    return res.join(' ')
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

end   # module Play

