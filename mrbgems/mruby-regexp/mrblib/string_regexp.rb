class String
  # Capture the C-defined String#split under `__split` before the override
  # below replaces it, so the override can delegate non-regexp patterns
  # back to the core implementation.
  alias __split split

  def match(re, pos = 0)
    re = Regexp.new(re) if re.is_a?(String)
    re.match(self, pos)
  end

  def match?(re, pos = 0)
    re = Regexp.new(re) if re.is_a?(String)
    re.match?(self, pos)
  end

  def =~(re)
    re =~ self
  end

  def sub(pattern, replacement = nil, &block)
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    unless block
      return pattern.__sub_str(self, replacement.to_s)
    end
    md = pattern.match(self)
    return self.dup unless md
    md.pre_match + block.call(md[0]).to_s + md.post_match
  end

  def gsub(pattern, replacement = nil, &block)
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    unless block
      return pattern.__gsub_str(self, replacement.to_s)
    end
    # block case: keep in Ruby to avoid VM callback from C
    parts = []
    pos = 0
    len = self.bytesize
    while pos <= len
      md = pattern.match(self, pos)
      break unless md
      match_start = md.begin(0)
      match_end = md.end(0)
      parts << self.byteslice(pos, match_start - pos)
      parts << block.call(md[0]).to_s
      if match_start == match_end
        rest = self.byteslice(match_end..-1)
        if rest && rest.bytesize > 0
          char = rest[0]
          parts << char
          pos = match_end + char.bytesize
        else
          pos = match_end + 1
        end
      else
        pos = match_end
      end
    end
    parts << self.byteslice(pos..-1)
    parts.join
  end

  def scan(pattern)
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    result = pattern.__scan(self)
    if block_given?
      result.each { |m| yield m }
      self
    else
      result
    end
  end

  # Regexp-aware split.  Falls back to the C-defined split (aliased as
  # `__split` in mrb_mruby_regexp_gem_init before this override loads) for
  # nil or string patterns, and handles regexp patterns in Ruby.
  def split(pattern = nil, *args)
    if args.length > 1
      raise ArgumentError, "wrong number of arguments (given #{args.length+1}, expected 0..2)"
    end

    limit_given = args.length > 0
    limit = limit_given ? args[0] : 0
    if pattern.nil? || pattern.is_a?(String)
      return limit_given ? __split(pattern, limit) : __split(pattern)
    end
    result = []
    rest = self
    count = 0
    return result if rest.length == 0
    while rest.length > 0
      if limit > 0 && count >= limit - 1
        result << rest
        return result
      end
      md = pattern.match(rest)
      break unless md
      result << md.pre_match
      rest = md.post_match
      count += 1
      # skip zero-length match at beginning
      if md[0].length == 0
        if rest.length > 0
          result[-1] = result[-1] + rest[0]
          rest = rest[1..-1] || ""
        end
      end
      i = 1
      while i < md.length
        result << md[i] unless md[i].nil?
        i += 1
      end
    end
    result << rest
    # remove trailing empty strings if no limit or zero limit
    if !limit_given || limit == 0
      while result.length > 0 && result[-1] == ""
        result.pop
      end
    end
    result
  end
end
