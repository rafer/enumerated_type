# EnumeratedType

Dead simple enumerated types for Ruby.

## Background

This gem implements the familiar notion of enumerated types in Ruby.

"But this is Ruby," you say, "where we haven't any use for such things." Yep. In Ruby, you can get a long way without any formalized concept of enumerated types by using symbols. Let's take the fairly typical example of a "status" field on the `Job` class:

```ruby
class Job
  attr_reader :status

  def initialize
    @status = :pending
  end

  def process
    begin
      # Do work here...
      @status = :success
    rescue
      @status = :failure
    end
  end
end
```

At first pass this seems fine. Any code that needs to act based on a job's status has to have magic symbols (i.e. `job.status == :success`), but maybe that's OK for a little while. Later, though, we might want to add a little logic around the `Job`'s status, something like:

```ruby
# In something like a JobNotifier class
if job.status == :failure or job.status == :success
  # Email user to let them know about their job
end
```

At this point, it's starting to feel like a little bit too much knowledge about the `Job` has slipped into other classes; any changes to the in the way status is handled in `Job` will require change in other classes because they've been exposed to the details of it's implementation. What, for example, if we want to add another "finished" state that a user should be notified of (say, `:partial_success`)? To deal with this we might create a predicate method that lets you interrogate a `Job` more abstractly about it's status:

```ruby
class Job
  # ...
  def done?
    [:failure, :success, :partial_success].include?(@status)
  end
end
```

Now, say we need another kind of job: the `AdminJob`. It needs to have the same set of statuses (with the same behavior as `Job`'s status). We could certainly move the status related code into a `StatusHaving` module and mix it in to both `Job` and `AdminJob`, but there are some drawbacks here, chief among them that we'd have to add a good bit of coupling between the `Job`, `AdminJob` and the `StatusHaving` mix-in module. For example both classes and the mix-in would need to agree on the `@status` instance variable. I would argue at this point the idea of a `JobStatus` should be promoted to it's own class, maybe with a little bit of error checking:

```ruby
class JobStatus
  NAMES = [:pending, :success, :failure]

  def initialize(name)
    unless NAMES.include?(name)
      raise ArugmentError.new("Invalid status #{name.inspect}")
    end

    @name = name
  end
end
```

and then in `Job`:

```ruby
class Job
  def initialize
    @status = JobStatus.new(:pending)
  end
end
```

There are some advantages to this approach:

  1. The list of all the possible statuses lives in *only one place*. I think it's way easier to look at the `JobStatus` class and see what the possible statuses are than it is to hunt through the `Job` class Looking for symbols assigned to `@status` (or, even worse, to look *outside* the `Job` class looking for assignments to Job#status).
  2. It's now possible to interact with the list of all legal statuses programmatically (perhaps in an admin console that has a drop down for of all statuses so that they may be manually updated).
  3. We can separate behavior (methods) that apply to the enumerated types from the classes that include one of these types (`Job` in our example). Although the status handling code in our version of `Job` was fairly simple, it often becomes clear that handling the status of a job is a very separate concern from the actual processing of a `Job`, and thus implementing both in a single class becomes a [Single Responsibility Principle](http://en.wikipedia.org/wiki/Single_responsibility_principle) violation.
  4. By separating the `JobStatus` behavior from the `Job`, we're able to more easily respond to change in requirements around the `JobStatus` in the future. Perhaps at some point we'll want to transform `JobStatus` into a state machine where only certain transitions are allowed, or include code that audits the change of state, etc.

"But all did was explain enumerated types, the kind that are present all over the place in other languages." Yep. That is correct. The only downside of the approach shown is that you have to re-create very similar, one-off implementations of an enumerated type. The `EnumeratedType` gem is just a clean and simple Ruby implementation of a well known concept.

## Usage

Define an enumerated type:

```ruby
class JobStatus
  include EnumeratedType

  declare :pending
  declare :success
  declare :failure
end
```

Get an instance of an enumerated type:

```ruby
# Via constant...
@status = JobStatus::PENDING

# Or via symbol...
@status = JobStatus[:pending]
@status = JobStatus[:wrong] #=> raises an ArgumentError
```

All instances have predicate methods defined automatically:

```ruby
@status = JobStatus::PENDING
@status.pending? # => true
@status.failure? # => false
```

Get the original symbol used to define the type:

```ruby
JobStatus::PENDING.name # => :pending
```

A class that includes `EnumeratedType` is just a regular Ruby class, so feel free to (and definitely do) add your own methods:

```ruby
class JobStatus
  #...
  def done?
    success? or failure?
  end
end
```

The only exception exception to the "just a regular ruby class" rule is that the constructor (`JobStatus.new`) is privatized.

Classes that include enumerated types themselves become enumerable, so you can do things like:

```ruby
JobStatus.map(&:name).sort.each { |n| puts "JobStatus: #{n}" }
```

## Bonus Features

Create enumerated types with ultra-low ceremony:

```ruby
JobStatus = EnumeratedType.new(:pending, :success, :failure)
```

Add arbitrary attributes:

```ruby
class JobStatus
  include EnumeratedType

  declare :pending, :message => "Your Job is waiting to be processed"
  declare :success, :message => "Your Job has completed"
  declare :failure, :message => "Oops, it looks like there was a problem"
end

JobStatus::SUCCESS.message # => "Your job has completed"
```

Coerce from other types:

```ruby
JobStatus.coerce(:pending)           # => #<JobStatus:pending>
JobStatus.coerce("pending")          # => #<JobStatus:pending>
JobStatus.coerce(JobStatus::PENDING) # => #<JobStatus:pending>
JobStatus.coerce(nil)                # => raises a TypeError
JobStatus.coerce(1)                  # => raises a TypeError
JobStatus.coerce(:wrong)             # => raises an ArgumentError
```

`.coerce` is particularly useful for scrubbing parameters, allowing you to succinctly assert that arguments are valid for your `EnumeratedType`, while also broadening the range of types that can be used as input. Using `.coerce` at the boundaries of your code allows clients the freedom to pass in full fledged `EnumeratedType` objects, symbols or even strings, and allows you to use the `.coerce`d input with confidence (i.e without any type or validity checking beyond the call to `.coerce`).

## Development

To run the tests (assuming you have already run `gem install bundler`):

    bundle install && bundle exec rake
