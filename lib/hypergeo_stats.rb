
module HStats
  class HypergeoStats
		@@fact = [0,0,0.693147180559945,1.791759469228055,3.178053830347946,4.787491742782046,6.579251212010101,8.525161361065415,
								 10.60460290274525,12.80182748008147,15.10441257307552,17.50230784587389,19.98721449566188,22.55216385312342,
								 25.19122118273868,27.89927138384089,30.6718743941422, 33.5050860689909, 36.3954564338402, 39.3398942384233, 42.335625512472, 45.3801470926379]; # A list of factorial values of their respective reference nu
		@@nk={}
		@@lnFact={}

		def ln_n_choose_k(n,k)
			if(@@nk["#{n}-#{k}"])
				return @@nk["#{n}-#{k}"]
			end
			#die "improper k: k, n: n\n" if k > n or k < 0;
			k = (n - k) if (n - k) < k;
			@@lnFact[n] = lnFact(n) unless @@lnFact[n];
			@@lnFact[k] = lnFact(k) unless @@lnFact[k];
			@@lnFact[n-k] = lnFact(n-k) unless @@lnFact[n-k];
			result = @@lnFact[n]-@@lnFact[k]-@@lnFact[n-k];
			@@nk["#{n}-#{k}"]=result;
			return result;
		end

		# Returns the natural log of the factorial of the value passed to it.  Uses Stirling's approximation for large factorials
		def lnFact(z) 
			if (z < @@fact.length) 
				return @@fact[z]
			end
			return lnStirling(z);
		end

		def lnStirling(x) # For large values of n, (n/e)n square root(2n pi) < n! < (n/e)n(1 + 1/(12n-1)) square root(2n pi): Stirling's Formula.
			s = 0.5*(Math.log(2*Math::PI)) + 0.5*(Math.log(x)) + x*(Math.log(x)) - x;
			upadd = Math.log(1 + (1/(12*x - 1)));
			approx = s + upadd; # using the upper bound gives more conservative (and accurate) p-values.
			return approx;
		end
		
		def lnHypergeometric(gp,tg,tp,t) # Returns the p-value for a particular overlap
			#print "2nd -> ($gp, $tg, $tp, $t)<br/>";
			return 0 if ((t - tg) < (tp - gp))
			return ln_n_choose_k(tg, gp) + ln_n_choose_k((t - tg), (tp - gp)) - ln_n_choose_k(t, tp);
		end

		def cum_hyperg_pval_info(gp,tg,tp,t) 
			return [1, "tg == t, what did you expect?"] if(tg==t)
			return [1, "tg == 0, what did you expect?"] if(tg==0)
			return [1, "represented?: #{gp}|#{tp}|#{tg}|#{t}"] if(tp==t && tg == gp)
			# die "ERROR: improper input values for hypergeometric distribution.\n" if gp<0 or gp>tg or gp>tp or tg<0 or tg>t or tp<0 or tp>=t or t<0;
			if (tg < tp) # setting B to the smaller of the two counts optimizes the p-value calculation
				temp = tp;
				tp = tg;
				tg = temp;
			end
			#print "1st -> (gp, tg, tp, t)<br/>";
			resultR=0
			resultL=0
			for i in gp..tp # sum from AB to right in distribution
				# exp = e ^ x (inverse of ln)
				right = lnHypergeometric(i,tg,tp,t);
				right = Math::E**right if(right != 0)
				resultR += right;
			end
			for i in 0..gp # sum from left to AB in distribution
				left = lnHypergeometric(i,tg,tp,t);
				left = Math::E**left if(left != 0)
				resultL += left;
			end
			# pick the smaller of the two sections of the distribution as it is the one that is in the tail instead of around the mean and a tail...meaning that
			# which ever is smaller tells us if we are over or under represented....
			return [resultR,"OVER-REPRESENTED"] if (resultR < resultL) # OVER-REPRESENTED
			return [-1*resultL,"UNDER-REPRESENTED"]
		end
		
	end
end
