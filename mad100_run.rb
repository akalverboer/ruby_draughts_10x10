#!/usr/bin/env ruby

# =====================================================================================
# MAD100 is a draughts engine for the 100 squares board.
# This module implements the user interface for running MAD100.
# =====================================================================================

require 'set'
require_relative 'mad100'          # module Main
require_relative 'mad100_play'     # module Play
require_relative 'mad100_search'   # module Search
require_relative 'mad100_moves'    # module Moves

###############################################################################
# Class extensions
###############################################################################

class Array
   def sum
      inject(0) { |sum, x| sum + x}
   end
end

class String
   def isupper?
      return false if self.size > 1
      ('A'..'Z').include? self
   end
   def islower?
      return false if self.size > 1
      ('a'..'z').include? self
   end
end

# ================================================================================
module Run
   # Module for toplevel methods and constants.

   # MAD100 doesn't know about colors. Now we have to.
   WHITE, BLACK = 0, 1

end  # module Run

###################################################################################
def main
   puts("===========================================================")
   puts("| MAD100: Ruby engine for draughts 100 international rules | ")
   puts("===========================================================")

   stack = []
   stack.push 'new'             # initial board
   stack.push 'nodes 1000'      # initial level max_nodes
   ptr = -1                     # move pointer
   pv_list = []

   while true
      if stack != [] then
         comm = stack.pop
      else
         print "Command: "
         comm = gets.chomp.strip   # read input
      end

      case comm
         when /^q/      # startswith 'q': quit
            puts "Bye"
            break

         when /^nodes/
            # Set max_nodes to search
            if comm.split(" ").size == 1
               max_nodes = Search::MAX_NODES  # DEFAULT
            elsif comm.split(" ").size >= 2
               max_nodes = comm.split(" ")[1].to_i
            end
            puts "   Level max nodes: #{max_nodes}"

         when /^new/
            # Setup new position
            b = 0  # TEST different positions
            if b == 0 then
               board = Main::INITIAL_EXT
            elsif b == 1 then
               board = Main::INITIAL_EXT_TEST
            elsif b == 2 then
               board = Main::INITIAL_EXT_PROBLEM1   # test problem solving 1
            end

            pos = Main.newPos(board)
            color = Run::WHITE            # WHITE / BLACK
            Search.set_tp( Hash.new(nil) )       # reset transposition table
            Moves.clearTable()
            Play.mprint_pos(color, pos)

         when /^fen/
            # setup position with fen string (!!! without apostrophes and no spaces !!!)
            next if comm.split.size != 2
            _, fen = comm.split
            pos = Play.parseFEN(fen)     # module Play
            color = fen[0] == 'B' ? Run::BLACK : Run::WHITE
            Search.set_tp( Hash.new(nil) )       # reset transposition table
            Moves.clearTable()
            Play.mprint_pos(color, pos)

         when /^eval/
            # Evaluate position
            Play.mprint_pos(color, pos)
            puts "Score position: " + pos.score.to_s

         when /^legal/
            Play.mprint_pos(color, pos)
            lstring = ''
            Moves.gen_moves(pos).each do |lmove|
               lstring += Play.mrender_move(color, lmove) + '  '
            end
            puts 'Legal moves: ' + lstring

         when /^go/
            if comm.split.size == 1 then
               # MTD-bi search for next move
               origc = color
               start = Time.now
               move, score = Search.search(pos, max_nodes)
               finish = Time.now
               puts "Time elapsed: " + (finish - start).inspect

               pv_list = Play.gen_pv( pos, Search.get_tp ).map do |entry| entry end  # to array
               ptr = -1
               puts 'Principal Variation: %s' % ( Play.render_pv(origc, pos, Search.get_tp) )

            elsif comm.split.size == 2 then
               _, action = comm.split
               if action == 'f' then
                  # *** search for forced combinations ***
                  origc = color
                  start = Time.now
                  move, score = Search.search_pvf(pos, max_nodes)
                  finish = Time.now
                  puts "Time elapsed: " + (finish - start).inspect

                  pv_list = Play.gen_pv( pos, Search.get_tpf ).map do |entry| entry end  # to array
                  ptr = -1
                  puts 'Principal Variation: %s' % ( Play.render_pv(origc, pos, Search.get_tpf) )
               elsif  action == 'ab' then
                  # *** search with alpha-beta pruning ***
                  origc = color
                  start = Time.now
                  move, score = Search.search_ab(pos, max_nodes)
                  finish = Time.now
                  puts "Time elapsed: " + (finish - start).inspect

                  pv_list = Play.gen_pv( pos, Search.get_tpab ).map do |entry| entry end  # to array
                  ptr = -1
                  puts 'Principal Variation: %s' % ( Play.render_pv(origc, pos, Search.get_tpab) )
               else
                  puts 'Unknow action: #{action}'
               end
            end

            # We don't play well once we have detected our death
            if move == nil then
                puts "no move found; score: #{score}"
            elsif score >= Search::MATE_VALUE then
                puts "very high score"
            elsif score <= -Search::MATE_VALUE then
                puts "very low score"
            else
               puts 'Best move: ' + Play.mrender_move(color, move)
            end

         when /^pv/
            if comm.split.size == 1 then
               stack.push 'pv >'    # do next move in PV
            elsif comm.split.size == 2 then
               _, action = comm.split
               if pv_list.size == 0 then
                  puts "No list of Principal Variation moves"
                  next
               end
               if action == '>' then
                  # do next move in PV
                  if ptr == (pv_list.size - 1) then
                     puts "End of Principal Variation list"
                     next
                  end
                  ptr += 1
                  move = pv_list[ptr].move

                  if Moves.isLegal(pos, move) then
                     puts 'Move done:' + Play.mrender_move(color, move)
                     pos = pos.domove(move)
                     color = 1-color      # alternating 0 and 1 (WHITE and BLACK)
                     Play.mprint_pos(color, pos)
                  else 
                     ptr -= 1
                     puts "Illegal move; first run go"
                  end
               elsif action == '<' then
                  # to previous position of PV
                  if ptr < 0 then
                     puts "Begin of Principal Variation list"
                     next
                  end
                  color = 1-color
                  pos = pv_list[ptr].pos
                  Play.mprint_pos(color, pos)
                  ptr -= 1

               elsif action == '<<' then
                  # reset starting position
                  color = origc
                  ptr = -1
                  pos = pv_list[0].pos
                  Play.mprint_pos(color, pos)
               elsif action == '>>' 
                  puts 'not used: >>'
               end
            end

         when /^m/
            if comm.split.size == 1 then
               start = Time.now
               move, score = Search.search(pos, max_nodes)  # SEARCH
               finish = Time.now
               puts "Time elapsed: " + (finish - start).inspect

               if move == nil then
                  puts 'no move found; score: #{score}'
               elsif score <= -Search::MATE_VALUE
                  puts 'very low score'
               elsif score >= Search::MATE_VALUE
                  puts 'very high score'
               else
                  puts 'Principal Variation: %s' % ( Play.render_pv(color, pos, Search.get_tp) )
                  puts 'Move done:' + Play.mrender_move(color, move)
                  pos = pos.domove(move)
                  color = 1-color      # alternating 0 and 1 (WHITE and BLACK)
                  Play.mprint_pos(color, pos)
               end
            elsif comm.split.size == 2 then
               _, smove = comm.split()
               smove = smove.strip
               re = Regexp.new '(^([0-5]?[0-9][-][0-5]?[0-9])$|^([0-5]?[0-9]([x][0-5]?[0-9])+)$)'
               match = smove.match re
               if match != nil then
                  steps = Play.mparse_move(color, smove)
                  lmove = Moves.match_move(pos, steps)

                  if Moves.isLegal(pos, lmove) then
                     ###puts 'MOVE: ' + lmove.inspect
                     pos = pos.domove(lmove)
                     color = 1-color      # alternating 0 and 1 (WHITE and BLACK)
                     Play.mprint_pos(color, pos)
                  else
                     puts "Illegal move; please enter a legal move"
                  end
               else
                  # Inform the user when invalid input is entered
                  puts "Please enter a move like 32-28 or 26x37"
               end
            end

         when /^book/
            # *** init opening book ***
            start = Time.now
            #Search.book_readFile('data/openbook_test15')
            Search.book_readFile('data/mad100_openbook')
            finish = Time.now
            puts "Time elapsed: " + (finish - start).inspect

         when /^ping/ 
            next if comm.split.size != 2
            _, num = comm.split
            puts 'pong' + num.to_s

         when /^[hH\?]/
            puts ' _________________________________________________________________  '
            puts '| Use one of these commands:  '
            puts '|  '
            puts '| q:           quit  '
            puts '| h:           this help info  '
            puts '| new:         setup initial position  '
            puts '| fen <fen>:   setup position with fen-string  '
            puts '| eval:        print score of position  '
            puts '| legal:       show legal moves  '
            puts '| nodes <num>: set max number of nodes for search (or default)  '
            puts '|  '
            puts '| m       : let computer search and play a move  '
            puts '| m <move>: do move (format: 32-28, 16x27, etc)  '
            puts '|  '
            puts '| pv: do moves of PV (principal variation) '
            puts '|   pv >  : next move  '
            puts '|   pv <  : previous move  '
            puts '|   pv << : first position  '
            puts '|  '
            puts '| go: search methods for best move and PV generation  '
            puts '|   go    : method 1 > MTD-bi  '
            puts '|   go f  : method 2 > forced variation  '
            puts '|   go ab : method 3 > alpha-beta search  '
            puts '|  '
            puts '| book: init opening book  '
            puts '|_________________________________________________________________  '
            puts 

         when /^test0/ 
            # *** test Performance ***
            # Most critical for speed is move generation, so we perform a test.
            lstring = ''

            t0 = Time.now
            for i in 1..3000
               Moves.gen_moves(pos).each do |lmove|
                  lstring += Play.mrender_move(color, lmove) + '  '
               end
            end
            t1 = Time.now

            puts "Time elapsed for test: " + (t1 - t0).inspect

         when /^test1/
            # *** test ***
            Moves.tableSize()

         else
            puts "   Error (unkown command): " + comm

      end   # case
   end   # while
end   # main


if $0 == __FILE__ then
   main
end


#######################################################################

