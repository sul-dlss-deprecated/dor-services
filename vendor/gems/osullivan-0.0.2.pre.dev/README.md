# OSullivan

[![Build Status](https://travis-ci.org/jpstroop/osullivan.svg?branch=development)](https://travis-ci.org/jpstroop/osullivan) [![Coverage Status](https://coveralls.io/repos/jpstroop/osullivan/badge.png?branch=development)](https://coveralls.io/r/jpstroop/osullivan?branch=development)

## Building New Objects

There is (or will be) a class for all types in [IIIF Presentation API Spec](http://iiif.io/api/presentation/2.0/).

After you've installed the gem (not yet published. Clone and do `rake:install`):

```ruby
require 'iiif/presentation'

seed = {
    '@id' => 'http://example.com/manifest',
    'label' => 'My Manifest'
}
# Any options you add are added to the object
manifest = IIIF::Presentation::Manifest.new(seed)

canvas = IIIF::Presentation::Canvas.new()
# All classes act like `ActiveSupport::OrderedHash`es, for the most part.
# Use `[]=` to set JSON-LD properties...
canvas['@id'] = 'http://example.com/canvas'
# ...but there are also accessors and mutators for the properties mentioned in 
# the spec
canvas.width = 10
canvas.height = 20
canvas.label = 'My Canvas'

oc = IIIF::Presentation::Resource.new('@id' => 'http://example.com/content')
canvas.other_content << oc

manifest.sequences << canvas

puts manifest.to_json(pretty: true)
```

Methods are generated dynamically, which means `#methods` is your friend:

```ruby
manifest = IIIF::Presentation::Manifest.new()
puts manifest.methods(false)
> label=
> label
> description=
> description
> thumbnail=
> thumbnail
> attribution=
> attribution
> viewing_hint=
> viewingHint=
> viewing_hint
> viewingHint
[...]
```

Note that multi-word properties are implemented as snake_case (because this is
Ruby), but is serialized as camelCase. There are camelCase aliases for these.

```ruby
manifest = IIIF::Presentation::Manifest.new()
manifest.viewing_hint = 'paged'
puts manifest.to_json(pretty: true, force: true) # force: true skips validations

> {
>   "@context": "http://iiif.io/api/presentation/2/context.json",
>   "@type": "sc:Manifest",
>   "viewingHint": "paged"
> }

```

## Parsing Existing Objects

Use `IIIF::Service#parse`. It will figure out what the object
should be, based on `@type`, and fall back to `ActiveSupport::OrderedHash` when
it can't e.g.:

```ruby
seed = '{
  "@context": "http://iiif.io/api/presentation/2/context.json",
  "@id": "http://example.com/manifest",
  "@type": "sc:Manifest",
  "label": "My Manifest",
  "service": {
    "@context": "http://iiif.io/api/image/2/context.json",
    "@id":"http://www.example.org/images/book1-page1",
    "profile":"http://iiif.io/api/image/2/profiles/level2.json"
  },
  "seeAlso": {
    "@id": "http://www.example.org/library/catalog/book1.marc",
    "format": "application/marc"
  },
  "sequences": [
    {
      "@id":"http://www.example.org/iiif/book1/sequence/normal",
      "@type":"sc:Sequence",
      "label":"Current Page Order",
      "viewingDirection":"left-to-right",
      "viewingHint":"paged",
      "startCanvas": "http://www.example.org/iiif/book1/canvas/p2",
      "canvases": [
        {
          "@id": "http://example.com/canvas",
          "@type": "sc:Canvas",
          "width": 10,
          "height": 20,
          "label": "My Canvas",
          "otherContent": [
            {
              "@id": "http://example.com/content",
              "@type":"sc:AnnotationList",
              "motivation": "sc:painting"
            }
          ]
        }
      ]
    }
  ]
}'

obj = IIIF::Service.parse(seed) # can also be a file path or a Hash
puts obj.class
puts obj.see_also.class

> IIIF::Presentation::Manifest
> ActiveSupport::OrderedHash
```

## Validation and Exceptions

This is work in progress. Right now exceptions are generally raised when you 
try to set something to a type it should never be:

```ruby
manifest = IIIF::Presentation::Manifest.new
manifest.sequences = 'quux'

> [...] sequences must be an Array. (IIIF::Presentation::IllegalValueError)
```

and also if any required properties are missing when calling `to_json`

```ruby
canvas = IIIF::Presentation::Canvas.new('@id' => 'http://example.com/canvas')
puts canvas.to_json(pretty: true)

> A(n) width is required for each IIIF::Presentation::Canvas (IIIF::Presentation::MissingRequiredKeyError)
```

but you can skip this validation by adding `force: true`:

```ruby
canvas = IIIF::Presentation::Canvas.new('@id' => 'http://example.com/canvas')
puts canvas.to_json(pretty: true, force: true)

> {
>   "@context": "http://iiif.io/api/presentation/2/context.json",
>   "@id": "http://example.com/canvas",
>   "@type": "sc:Canvas"
> }
```
This all needs a bit of tidying up, finishing, and refactoring, so expect it to 
change.
