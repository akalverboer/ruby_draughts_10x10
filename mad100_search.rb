#!/usr/bin/env ruby

#######################################################################################
# Implementation of search functions:
# 1. MTD-bi search
# 2. Forced variation: search only for moves that leads to a capture for the opponent.
# 3. Normal alpha-beta search with aspiration windows
# Implementation of an opening book.
#######################################################################################

module Search

TABLE_SIZE = 1e6  # constant of maximum number allowed items in transposition table.

# The MAX_NODES constant controls how much time we spend on looking for optimal moves.
# This is the default max number of nodes searched.
#
MAX_NODES = 1000

# The MATE_VALUE constant is the limit for stop searching 
#   score <= -MATE_VALUE: player won
#   score >=  MATE_VALUE: player lost
# Theoretical the mate value must be greater than the maximum possible score
#
MATE_VALUE = 90000

###############################################################################
# MTD-bi search
###############################################################################

Entry_tp = Struct.new(:depth, :score, :gamma, :move) 

@tp = Hash.new(nil)      # Transposition Table: dict of Entry_tp (not found >> nil)
def self.get_tp
   @tp
end
def self.set_tp(x)
   @tp = x
end

def self.bound(pos, gamma, depth)
    # Alpha-beta pruning with null-window defined by gamma: [alpha, beta] = [gamma-1, gamma]
    # Parameter gamma is a guess of the exact score. It plays a role in a null-window search
    # with window [gamma-1, gamma]. Cut off childs if the real score >= gamma.
    # 
    @nodes += 1

    # Look in the tranposition table if we have already searched this position before.
    # We use the table value if it was done with at least as deep a search as ours,
    # and the gamma value is compatible.
    #
    entry = @tp[pos.key()]     # key() is board string
    if entry != nil and depth <= entry.depth and (
          entry.score < entry.gamma and entry.score < gamma or
          entry.score >= entry.gamma and entry.score >= gamma ) then
       return entry.score      # Stop searching this node
    end

    # Stop searching if we have won/lost.
    if pos.score.abs >= MATE_VALUE then
       return pos.score
    end

    # NULL MOVE HEURISTIC. For increasing speed.
    # The idea is that you give the opponent a free shot at you. If your position is still so good
    # that you exceed gamma, you assume that you'd also exceed gamma if you went and searched all of your moves.
    # So you simply return gamma without searching any moves.
    #
    nullswitch = true    ### *** set ON/OFF *** ###
    r = (depth > 8) ? 3 : 2              # depth reduction
    if depth >= 4 and not Moves.hasCapture(pos) and nullswitch then
       child = pos.rotate()    # position of opponent without move of player
       nullscore = -bound(child, 1-gamma, depth-1-r)     # RECURSION
       if nullscore >= gamma then
          return nullscore      # Nullscore high: stop searching this node
       end
    end

    # Evaluate or search further until end-leaves has no capture(s) (QUIESCENCE SEARCH)
    if depth <= 0 and not Moves.hasCapture(pos) then
       return pos.score    # Evaluate position
    end

    # We generate all possible legal moves and order them to provoke cuts.
    # At the next level of the tree we are going to minimize the score.
    # This can be shown equal to maximizing the negative score, with a slightly
    # adjusted gamma value.
    #
    best, bmove = -MATE_VALUE, nil
    moveList = Moves.gen_moves(pos).sort_by { |move| pos.eval_move(move) }.reverse

    moveList.each do |move|
       # Iterate over the sorted generator
       score = -1 * bound(pos.domove(move), 1-gamma, depth-1)   # RECURSION
       if score > best then
          best = score
          bmove = move
       end
       break if score >= gamma   # CUT OFF
    end

    # UPDATE TRANSPOSITION TABLE
    # We save the found move together with the score, so we can retrieve it in the play loop.
    # We also trim the transposition table in FILO order.
    # We prefer fail-high moves, as they are the ones we can build our PV (Principal Variation) from.
    # Depth condition: we prefer an entry with higher depth value.
    #    So replace the already retrieved entry if depth >= entry.depth
    #
    if entry == nil or ( depth >= entry.depth and best >= gamma ) then
        @tp[pos.key()] = Entry_tp.new(depth, best, gamma, bmove)
        if @tp.size > TABLE_SIZE then
            @tp.shift   # removes an arbitrary (key,value) pair
        end
    end
    return best
end   # bound

def self.search(pos, maxn=MAX_NODES)
    # Iterative deepening MTD-bi search, the bisection search version of MTD
    # See the term "MTD-f" at wikipedia.

    move = book_searchMove(pos)
    if move != nil then
       puts 'Move from opening book'
       depth, score, gamma, move = 0, pos.score, nil, move
       @tp[pos.key()] = Entry_tp.new(depth, score, gamma, move)
       if @tp.size > TABLE_SIZE then
          @tp.shift   # removes an arbitrary (key,value) pair
       end
       return move, pos.score
    end

    @nodes = 0
    if @tp.size > (TABLE_SIZE / 2) then
       @tp = Hash.new(nil)            # empty hash table when half full
    end
    
    puts "thinking ....   max nodes: #{maxn}" 
    puts '%8s %8s %8s %8s' %['depth', 'nodes', 'gamma', 'score']   # header

    # We limit the depth to some constant, so we don't get a stack overflow in the end game.
    for depth in 1..99
        # The inner loop is a binary search on the score of the position.
        # Inv: lower <= score <= upper
        # However this may be broken by values from the transposition table,
        # as they don't have the same concept of p(score). Hence we just use
        # 'lower < upper - margin' as the loop condition.
        lower, upper = -MATE_VALUE, MATE_VALUE
        while lower < upper - 3
            gamma = (lower+upper+1).div 2      # bisection !!   gamma === beta
            score = bound(pos, gamma, depth)   # AlphaBetaWithMemory
            if score >= gamma then
                lower = score
            end
            if score < gamma then
                upper = score
            end
        end

        puts '%8d %8d %8d %8d' %[depth, @nodes, gamma, score]

        # We stop deepening if the global node counter shows we have spent too long for this depth
        break if @nodes >= maxn

        # We stop deepening if we have already won/lost the game.
        break if score.abs >= MATE_VALUE
    end  # for

    # We can retrieve our best move from the transposition table.
    entry = @tp[pos.key()]
    if entry != nil then
        return entry.move, entry.score
    end
    return nil, score       # move unknown
end   # search

###############################################################################
# Search logic for Principal Variation Forced (PVF)
###############################################################################

Entry_tpf = Struct.new(:depth, :score, :move) 

@tpf = Hash.new(nil)      # Transposition Table: dict of Entry_tpf (not found >> nil)
def self.get_tpf
   @tpf
end
def self.set_tpf(x)
   @tpf = x
end

def self.minimax_pvf(pos, depth, player)
   # Fail soft negamax ab-pruning for forced principal variation
   # Parameter player: alternating +1 and -1 (player resp. opponent)
   # Test for dedicated problems shows: can be much faster than MTD-bi search 

   @xnodes += 1

   # Read transposition table
   entry = @tpf[pos.key()]
   if entry != nil and depth <= entry.depth then
      return entry.score      # Stop searching this node
   end

   # Evaluate or search further until end-leaves has no capture(s) (QUIESCENCE SEARCH)
   if depth <= 0 and not Moves.hasCapture(pos) then
      return pos.score    # Evaluate position
   end

   best, bmove = -MATE_VALUE, nil
   moveList = Moves.gen_moves(pos).map do |move| move end  # to array

   #   mCount = moveList.size   # count moves
   #   if mCount == 0 then
   #      return -MATE_VALUE    # no moves at all, lost
   #   end

   mCount = 0
   moveList.each do |move|
      child = pos.domove(move)

      if player == 0 then
         if move.takes.size == 0 and not Moves.hasCapture(child) then
            # Player decides only to look at moves that leads to a capture for the opponent.
            # But captures of the player are always inspected.
            next
         end
      end

      if player == 1 then
         next if move.takes.size == 0    # Inspect only captures for opponent 
      end

      # PRINT TREE
      ## puts '===' * depth + '> ' + Play.mrender_move(player, move)

      mCount += 1
      score = -minimax_pvf(child, depth-1, 1-player)
      if score > best then
         best = score
         bmove = move
      end
   end

   if mCount == 0 then      # stop: no moves that leads to a capture for the opponent.
      return pos.score
   end

   # Write transposition table
   if entry == nil or depth >= entry.depth then
      @tpf[pos.key()] = Entry_tpf.new(depth, best, bmove)
      if @tpf.size > TABLE_SIZE then
         @tpf.shift   # removes an arbitrary (key,value) pair
      end
   end
   return best
end

def self.search_pvf(pos, maxn=MAX_NODES)
   # Iterative deepening of forced variation sequence.
   @xnodes = 0
   player = 0            # 0 = starting player; 1 = opponent 
   if @tpf.size > (TABLE_SIZE / 2) then
       @tpf = Hash.new(nil)            # empty hash table when half full
   end
   
   puts "thinking ....   max nodes: #{maxn}" 
   puts '%8s %8s %8s' %['depth', 'nodes', 'score']   # header

   for depth in 1..99
      best = minimax_pvf(pos, depth, player)

      ## REPORT
      puts '%8d %8d %8d' %[depth, @xnodes, best]
      #print(render_pv(0, pos, tpf))

      # We stop deepening if the global N counter shows we have spent too long for this depth
      break if @xnodes >= maxn

      # Looking for another stop criterium.
      # Sometimes a solution is found but search is going on until max nodes is reached.
      # We like to stop sooner and prevent waiting. But which stop citerium?
   end

   # We can retrieve our best move from the transposition table.
   entry = @tpf[pos.key()]
   if entry != nil then
      return entry.move, best
   end
   return nil, best       # move unknown
end


###############################################################################
# Normal alpha-beta search with aspiration windows
###############################################################################

Entry_tpab = Struct.new(:depth, :score, :move) 

@tpab = Hash.new(nil)      # Transposition Table: dict of Entry_tpab (not found >> nil)
def self.get_tpab
   @tpab
end
def self.set_tpab(x)
   @tpab = x
end

def self.alphabeta(pos, alpha, beta, depthleft, player)
   # Fail soft: function returns value that may exceed its function call arguments.
   # Separate player code for better understanding.
   # Use of the transposition table tpab 
   # TEST: uses 30-50% MORE nodes than MTD-bi search for getting the same result

   @ynodes += 1

   # Read transposition table
   entry = @tpab[pos.key()]
   if entry != nil and depthleft <= entry.depth then
      return entry.score      # We know already the result: stop searching this node
   end

   # Stop searching if we have won/lost.
   if pos.score.abs >= MATE_VALUE then
      return pos.score
   end

   # NULL MOVE HEURISTIC. For increasing speed.
   # The idea is that you give the opponent a free shot at you. If your position is still so good
   # that you exceed beta, you assume that you'd also exceed beta if you went and searched all of your moves.
   # So you simply return beta without searching any moves.
   #
   nullswitch = true    ### *** set ON/OFF *** ###
   r = (depthleft > 8) ? 3 : 2              # depth reduction
   if depthleft >= 4 and not Moves.hasCapture(pos) and nullswitch then
      child = pos.rotate()    # position of opponent without move of player
      nullscore = alphabeta(child, alpha, alpha+1, depthleft-1-r, 1-player)   # RECURSION
      if player == 0 then
         return beta if nullscore >= beta    # Nullscore high: stop searching this node
      end
      if player == 1 then
         return alpha if nullscore <= alpha  # Nullscore low: stop searching this node
      end
   end

   moveList = Moves.gen_moves(pos).sort_by { |move| pos.eval_move(move) }.reverse

   if player == 0 then
      # Evaluate or search further until end-leaves has no capture(s) (QUIESCENCE SEARCH)
      if depthleft <= 0 and not Moves.hasCapture(pos) then
         return pos.score    # Evaluate position
      end

      bestValue = -MATE_VALUE 
      bestMove = nil
      alphaMax = alpha        # clone of alpha (we do not want to change input parameter)

      moveList.each do |move|
         child = pos.domove(move)
         score = alphabeta(child, alphaMax, beta, depthleft-1, 1-player)   # RECURSION

         if score > bestValue then
            bestValue = score           # bestValue is running max of score
            bestMove = move
         end

         alphaMax = [alphaMax, bestValue].max  # alphaMax is running max of alpha
         break if alphaMax >= beta             # beta cut-off
      end
   end
   if player == 1 then
      # Evaluate or search further until end-leaves has no capture(s) (QUIESCENCE SEARCH)
      if depthleft <= 0 and not Moves.hasCapture(pos) then
         return -1 * pos.score    # Evaluate position
      end

      bestValue = MATE_VALUE  
      bestMove = nil
      betaMin = beta          # clone of beta

      moveList.each do |move|
         child = pos.domove(move)
         score = alphabeta(child, alpha, betaMin, depthleft-1, 1-player) 
         if score < bestValue then
            bestValue = score                  # bestValue is running min of score
            bestMove = move
         end
         betaMin = [betaMin, bestValue].min    # betaMin is running min of beta
         break if betaMin <= alpha             # alpha cut-off
      end
   end

   # Write transposition table
   if entry == nil or depthleft >= entry.depth then
      @tpab[pos.key()] = Entry_tpab.new(depthleft, bestValue, bestMove)
      if @tpab.size > TABLE_SIZE then
         @tpab.shift   # removes an arbitrary (key,value) pair
      end
   end

   return bestValue
end

def self.search_ab(pos, maxn=MAX_NODES)
   # Iterative deepening alpha-beta search enhanced with aspiration windows
   @ynodes = 0
   if @tpab.size > (TABLE_SIZE / 2) then
       @tpab = Hash.new(nil)            # empty hash table when half full
   end

   lower, upper = -MATE_VALUE, MATE_VALUE
   valWINDOW = 50         # ASPIRATION WINDOW: tune for optimal results

   puts "thinking ....   max nodes: #{maxn}" 
   puts '%8s %8s %8s %8s %8s' %['depth', 'nodes', 'score', 'alpha', 'beta']   # header

   # We limit the depth to some constant, so we don't get a stack overflow in the end game.
   alpha, beta = lower, upper
   depthleft = 1
   while depthleft < 100
      player = 0            # 0 = starting player is max; 1 = opponent 
      score = alphabeta(pos, alpha, beta, depthleft, player)

      ## REPORT
      puts '%8d %8d %8d %8d %8d' %[depthleft, @ynodes, score, alpha, beta]

      # We stop deepening if the global N counter shows we have spent too long for this depth
      break if @ynodes >= maxn

      # We stop deepening if we have already won/lost the game.
      break if score.abs >= MATE_VALUE

      if score <= alpha or score >= beta then
         alpha, beta = lower, upper
         next   # sadly we must repeat with same depthleft
      end

      alpha, beta = score - valWINDOW, score + valWINDOW
      depthleft += 1
   end

   # We can retrieve our best move from the transposition table.
   entry = @tpab[pos.key()]
   if entry != nil then
      return entry.move, entry.score
   end
   return nil, score       # move unknown
end

###############################################################################
# Logic Opening book
###############################################################################
Entry_open = Struct.new(:freq)
@tp_open = Hash.new(nil)     # init/reset transposition table as global

def self.book_isPresent(f)
   return true if File.file?(f)
   return false
end

def self.book_readFile(f)
   # Read opening book
   if not book_isPresent(f) then
      put "Opening book not available: #{f}"
      return 0    # no opening book found
   end

   puts "Reading opening book <#{f}>  ...."
   @tp_open = Hash.new(nil)     # init/reset transposition table as global

   file = File.open(f, 'r')
   linecount = 0
   movecount = 0
   while line = file.gets do
      linecount += 1
      line = line.chomp.strip
      next if line == ''
      ###puts 'line: ' + line
      movecount += book_addLine(line)
   end
   file.close
   puts "Opening book read: #{linecount} lines and #{movecount} positions"
end

def self.book_addLine(line)
   # Each line is an opening. Add entries to transposition table
   pos_start = Main.newPos(Main::INITIAL_EXT)  # starting position

   line2 = line.gsub( /[123456789]?[123456789]\./ , '')   # remove all move numbers
   #puts 'line2: ' + line2

   smoves = line2.split(' ')

   ##print('add new opening')
   pos = pos_start
   color = Run::WHITE
   movecount = 0
   smoves.each do |smove|
      steps = Play.mparse_move(color, smove)     # from mad100_play; TEMP HERE
      move = Moves.match_move(pos, steps) 
      if move == nil then
         puts "Illegal move in opening book; move #{smove}, line #{line}"
         break
      end

      pos = book_addEntry(pos, move)  # update pos with move
      color = 1 - color      # alternating 0 and 1 (WHITE and BLACK)
      movecount += 1
   end

   return movecount
end

def self.book_addEntry(pos, move)
   # Add entry for opening book to transposition table

   posnew = pos.domove(move)
   key = posnew.key()
   entry = @tp_open[key] 
   if entry == nil then
      freq = 1
      ##print('New entry:', move, freq)
      @tp_open[key] = Entry_open.new(freq) 
   else
      freq = entry.freq + 1
      ##print('New entry:', move, freq)
      @tp_open[key] = Entry_open.new(freq) 
   end
   return posnew
end

def self.book_searchMove(pos)
   # Returns a move from pos which results in a position from the opening book
   candidates = []      # array of candidate moves
   entry_cand = Struct.new(:move, :freq)
   Moves.gen_moves(pos).each do |move|
      posnew = pos.domove(move)
      entry = @tp_open[posnew.key()] 
      if entry != nil then
         ##print('move:', move)
         candidates.push entry_cand.new(move, entry.freq)
      end
   end

   if candidates.size > 0 then
      # Two strategies to select one candidate move
      # 1. Select move with highest frequence
      # 2. Select a random candidate move
      candidates.sort_by! { |c| c.freq }.reverse

      s = 1       # which choice
      if s == 0 then
         high_i = 0                                        # highest freq after sort
         sel_move = candidates[high_i].move 
         ##puts 'candidate highest freq: ' candidates[high_i].move.inspect + ' ' + candidates[high_i].freq.inspect 
      end
      if s == 1 then
         rand_i = rand( 0 .. (candidates.size - 1) )   # random index
         sel_move = candidates[rand_i].move
         ##puts 'candidate random: ' candidates[rand_i].move.inspect + ' ' + candidates[rand_i].freq.inspect
      end
      return sel_move
   else
      return nil
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

end   # module Search
