# URLImageView

URL image loading and caching for iOS.

# Example

```
override func viewDidLoad() {
    super.viewDidLoad()

    imageView.showsURLSpinner = true
    imageView.url = url

    button.setImageFilter(for: .normal) { (image) in image?.monoFiltered() }
    button.setURL(for: .normal, url)
    button.setURL(for: .selected, url)
}
```

# License

MIT
