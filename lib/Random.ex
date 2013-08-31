# Ported from Python 3
# See: http://hg.python.org/cpython/file/8c768bbacd92/Lib/random.py
# 
# Translated by Guido van Rossum from C source provided by
# Adrian Baddeley.  Adapted by Raymond Hettinger for use with
# the Mersenne Twister and os.urandom() core generators.
# Ported to Elixir by Yuce Tekol.


defmodule Random do
  use Bitwise
  
  @moduledoc """
  This module contains pseudo-random number generators for various distributionsported from Python 3 `random` module The documentation below is adapted from that module as well.

  For integers, there is uniform selection from a range. For sequences, there is uniform selection of a random element, a function to generate a random permutation of a list in-place, and a function for random sampling without replacement.

  On the real line, there are functions to compute uniform, normal (Gaussian), lognormal, negative exponential, gamma, and beta distributions. For generating distributions of angles, the von Mises distribution is available.
  """

  @nv_magicconst 4 * :math.exp(-0.5) / :math.sqrt(2.0)
  @twopi 2 * :math.pi
  @log4 :math.log(4)
  @sg_magicconst 1 + :math.log(4.5)
  @bpf 53
  @recip_bpf :math.pow(2, -@bpf)
  @maxwidth 1 <<< @bpf
  @e 2.71828

  defexception ValueError, message: "ValueError", can_rety: false do
    def full_message(self), do: "ValueError: #{self.message}" 
  end
  
  @doc """
  Return x % y
  """
  def mod(x, y), do: rem(rem(x, y) + y, y)

  #@doc """
  #Return a random number in range [0.0, 1.0)
  #"""
  defmacrop prandom do
    quote do
      r = :random.uniform
      if r === 1.0, do: 0.0, else: r
    end
  end

  defmacrop random_int(n) do
    quote do
      r = :random.uniform
      if r === 1.0, do: 0, else: trunc(r * unquote(n))
    end
  end

  @doc """
  Returns a random integer from range(start, stop[, step]).
  """
  def randrange(stop) do
    randrange(0, stop, 1)
  end

  def randrange(start, stop) do
    randrange(start, stop, 1)
  end

  def randrange(start, stop, step)
      when trunc(start) != start or
        trunc(stop) != stop or
        trunc(step) != step do
    throw ValueError[message: "non-integer argument for randrange(#{start}, #{stop}, #{step}"]
  end


  #def randrange(start, stop, _step)
  #    when stop <= start do
  #  throw ValueError[message: "stop must be greater than start for randrange(#{_start}, #{_stop}, #{step}"]
  #end

  def randrange(start, stop, step)
      when step == 1 do
    width = stop - start
    if width > 0 do
      if width >= @maxwidth do
        start + randbelow(width)
      else
        start + random_int(width)
      end
    else
      throw ValueError[message: "empty range for randrange(#{start}, #{stop}, #{step}"]
    end
  end

  def randrange(start, stop, step) do
    width = stop - start
    n = cond do
      step > 0 ->
        trunc((width + step - 1) / step)
      step < 0 ->
        trunc((width + step + 1) / step)
      true ->
        throw ValueError[message: "zero step for randrange(#{start}, #{stop}, #{step}"]
    end

    if n <= 0 do
      throw ValueError[message: "empty range for randrange(#{start}, #{stop}, #{step})"]
    end

    if n >= @maxwidth do
      start + step * randbelow(n)
    else
      start + step * random_int(n)
    end
  end

  defp randbelow(n), do: random_int(n)

  @doc """
  Return a random integer N such that a <= N <= b. Alias for Random.randrange(a, b+1).
  """
  def randint(a, b), do: randrange(a, b + 1)
  
  @doc """
  Returns a random element from a non-empty sequence.

  If `seq` is a list, converts it to a tuple before picking.
  """
  def choice(a..b)
      when b >= a do
    n = b - a + 1
    random_int(n) + a
  end

  def choice(seq)
      when is_list(seq) do
    tp = list_to_tuple(seq)
    choice(tp)
  end

  def choice(seq)
      when is_tuple(seq) do
    elem(seq, random_int(size(seq)))
  end
  
  @doc """
  Shuffle sequence `x`. This function is currently an alias for `Enum.shuffle/1`.

  Note that for even rather small `size(x)`, the total number of permutations of x is larger than the period of most random number generators; this implies that most permutations of a long sequence can never be generated.
  """
  def shuffle(x), do: Enum.shuffle(x)
  
  @doc """
  Chooses k unique random elements from a population sequence or set.

  Returns a new list containing elements from the population while
  leaving the original population unchanged. The resulting list is
  in selection order so that all sub-slices will also be valid random
  samples.  This allows raffle winners (the sample) to be partitioned
  into grand prize and second place winners (the subslices).

  Members of the population need not be unique. If the
  population contains repeats, then each occurrence is a possible
  selection in the sample.

  To choose a sample in a range of integers, use range as an argument.
  This is especially fast and space efficient for sampling from a
  large population: `Random.sample(0..10000000, 60)`
  """
  def sample(_pop, k)
      when k <= 0 do
    throw ValueError[message: "sample: k must be greater than 0"]
  end

  def sample(a..b, k)
      when b >= a and k <= (b - a + 1) do
    n = (b - a) + 1
    sel = HashSet.new
    Enum.map(sample_helper(n, k, sel, 0), &(a + &1))
  end

  def sample(pop, k)
      when is_list(pop) do
    sample(list_to_tuple(pop), k)
  end

  def sample(pop, k)
      when is_tuple(pop) do
    n = size(pop)
    sel = HashSet.new
    Enum.map sample_helper(n, k, sel, 0), &(elem(pop, &1))
  end
    
  defp sample_helper(n, k, sel, sel_size) do
    if sel_size < k do
      j = random_int(n)
      if Set.member?(sel, j) do
        sample_helper(n, k, sel, sel_size)
      else
        sel = Set.put(sel, j)
        sel_size = sel_size + 1
        sample_helper(n, k, sel, sel_size)
      end
    else
      Set.to_list(sel)
    end
  end

  def random, do: prandom
  def uniform(a, b), do: a + (b - a) * prandom

  @doc """
  Triangular distribution.

  Return a random floating point number N such that low <= N <= high and with the specified mode between those bounds. The low and high bounds default to zero and one. The mode argument defaults to the midpoint between the bounds, giving a symmetric distribution.

    http://en.wikipedia.org/wiki/Triangular_distribution
  """
  def triangular(low//0, high//1, mode//nil) do
    u = prandom
    c = if mode == nil, do: 0.5, else: (mode - low) / (high - low)
    if u > c do
      u = 1 - u
      c = 1 - c
      {low, high} = {high, low}
    end
    low + (high - low) * :math.pow(u * c, 0.5)
  end

  @oc """
  Normal distribution. mu is the mean, and sigma is the standard deviation.
  """
  def normalvariate(mu, sigma) do
    z = normalvariate_helper
    mu + z * sigma
  end
  
  defp normalvariate_helper do
    u1 = prandom
    u2 = 1.0 - prandom
    z = @nv_magicconst * (u1 - 0.5) / u2
    zz = z * z / 4.0

    if zz <= -:math.log(u2), do: z, else: normalvariate_helper
  end

  @doc """
  Log normal distribution. If you take the natural logarithm of this distribution, you’ll get a normal distribution with mean mu and standard deviation sigma. mu can have any value, and sigma must be greater than zero.
  """
  def lognormvariate(mu, sigma), do: :math.exp(normalvariate(mu, sigma))

  @doc """
  Exponential distribution. `lambda` is 1.0 divided by the desired mean. It should be nonzero. Returned values range from 0 to positive infinity if lambda is positive, and from negative infinity to 0 if lambda is negative.
  """
  def expovariate(lambda), do: -:math.log(1.0 - prandom) / lambda

  @doc """
  mu is the mean angle, expressed in radians between 0 and 2*pi, and kappa is the concentration parameter, which must be greater than or equal to zero. If kappa is equal to zero, this distribution reduces to a uniform random angle over the range 0 to 2*pi.
  """
  def vonmisesvariate(_mu, kappa)
    when kappa <= 1.0e-6, do: @twopi * prandom

  def vonmisesvariate(mu, kappa) do
    s = 0.5 / kappa
    r = s + :math.sqrt(1.0 + s * s)
    z = vonmisesvariate_helper(r)
    q = 1.0 / r
    f = (q + z) / (1.0 + q * z)
    u3 = prandom

    if u3 > 0.5 do
      mod((mu + :math.acos(f)), @twopi)
    else
      mod((mu - :math.acos(f)), @twopi)
    end

  end

  defp vonmisesvariate_helper(r) do
    u1 = prandom
    z = :math.cos(:math.pi * u1)
    d = z / (r + 2)
    u2 = prandom

    if (u2 < 1.0 - d * d) or (u2 <= (1.0 - d) * :math.exp(d)) do
      z
    else
      vonmisesvariate_helper(r)
    end
  end
  
  @doc """
  Gamma distribution.  Not the gamma function!
  Conditions on the parameters are alpha > 0 and beta > 0.

  The probability distribution function is:
  
    x ** (alpha - 1) * math.exp(-x / beta)<br>
    pdf(x) =  --------------------------------------<br>
    math.gamma(alpha) * beta ** alpha
  """
  def gammavariate(alpha, beta)
      when alpha <= 0 and beta <= 0 do
    throw ValueError[message: "gammavariate: alpha and beta must be > 0.0"]
  end

  def gammavariate(alpha, beta)
      when alpha > 1 do
    ainv = :math.sqrt(2 * alpha- 1)
    bbb = alpha - @log4
    ccc = alpha + ainv
    gammavariate_helper(alpha, beta, ainv, bbb, ccc)
  end
  
  def gammavariate(alpha, beta)
      when alpha == 1 do
    u = prandom
    if u <= 1.0e-7, do: gammavariate(alpha, beta)
    -:math.log(u) * beta
  end
  
  def gammavariate(alpha, beta) do
    u = prandom
    b = (@e + alpha) / @e
    p = b * u
    x = if p <= 1.0 do
      :math.pow(p, 1 / alpha)
    else
      -:math.log((b - p) / alpha)
    end
    u1 = prandom
    unless (p > 1 and u1 <= :math.pow(x, alpha - 1)) or (u1 <= :math.exp(-x)) do
      gammavariate(alpha, beta)
    end
    x * beta
  end
  
  defp gammavariate_helper(alpha, beta, ainv, bbb, ccc) do
    u1 = prandom
    if 1.0e-6 < u1 and u1 < 0.9999999 do
      u2 = 1 - prandom
      v = :math.log(u1 / (1 - u1)) / ainv
      x = alpha * :math.exp(v)
      z = u1 * u1 * u2
      r = bbb + ccc * v - x
      if r + @sg_magicconst - 4.5 * z >= 0 or r >= :math.log(z) do
        x * beta
      else
        gammavariate_helper(alpha, beta, ainv, bbb, ccc)
      end
    else
      gammavariate_helper(alpha, beta, ainv, bbb, ccc)
    end
  end
  
  @doc """
  Gaussian distribution.
  
    mu is the mean, and sigma is the standard deviation.  This is
    slightly faster than the `Random.normalvariate/2` function.
    
    Returns {number, gauss_next}
  """
  def gauss(mu, sigma, gauss_next//nil) do
    z = gauss_next
    gauss_next = nil
    if z == nil do
      x2pi = prandom * @twopi
      g2rad = :math.sqrt(-2 * :math.log(1 - prandom))
      z = :math.cos(x2pi) * g2rad
      gauss_next = :math.sin(x2pi) * g2rad
    end
    {mu + z * sigma, gauss_next}
  end 

  @doc """
  Beta distribution.

     Conditions on the parameters are alpha > 0 and beta > 0.
     Returned values range between 0 and 1.
   
  """
  def betavariate(alpha, beta) do
    y = gammavariate(alpha, 1.0)
    if y == 0, do: 0, else: y / (y + gammavariate(beta, 1))
  end
  
  @doc """
  Pareto distribution.
  
    alpha is the shape parameter.
  """
  def paretovariate(alpha) do
    u = 1 - prandom
    1 / :math.pow(u, 1 / alpha)
  end
  
  @doc """
  Weibull distribution.

    alpha is the scale parameter and beta is the shape parameter.
  """
  def weibullvariate(alpha, beta) do
    u = 1 - prandom
    alpha * :math.pow(-:math.log(u), 1 / beta)
  end
  
end  # module
