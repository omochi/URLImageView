import UIKit

internal final class UIImageViewEx {
    public unowned let view: UIImageView
    
    public let loader: URLImageLoader
    
    public var url: URL? {
        get { return _url }
        set {
            let oldValue = _url
            _url = newValue
            
            func needsStart() -> Bool {
                if oldValue != newValue {
                    return true
                }
                
                if let _ = newValue,
                    loader.image == nil
                {
                    return true
                }
                
                return false
            }
            
            if needsStart() {
                loader.url = newValue
                loader.start()
            }
        }
    }
    
    private var _url: URL?
    
    public var urlImage: UIImage? {
        get { return _urlImage }
        set {
            _urlImage = newValue
            
            renderURLImage()
            
            urlImageHandler?(_urlImage)
        }
    }
    
    private var _urlImage: UIImage?
    
    public var urlImageHandler: ((UIImage?) -> Void)?
    public var isURLLoadingHandler: ((Bool) -> Void)?
    public var showsURLSpinner: Bool = false
    public var spinner: UIActivityIndicatorView?
    public var urlImageFilter: ((UIImage?) -> UIImage?)?
    public var doesRenderWhenResized: Bool = false
    
    private var observations: [NSKeyValueObservation]!
    
    public init(view: UIImageView) {
        self.view = view
        self.loader = URLImageLoader()
        
        loader.imageHandler = { [weak self] (image) in
            guard let self = self else { return }
            
            self.urlImage = image
        }
        loader.isLoadingHandler = { [weak self] (isLoading) in
            guard let self = self else { return }
            
            if isLoading, self.showsURLSpinner {
                self.showURLSpinner()
            } else {
                self.hideURLSpinner()
            }
            
            self.isURLLoadingHandler?(isLoading)
        }
        self.observations = [
            view.observe(\.bounds) { [weak self] (_, _) in
                guard let self = self else { return }
                if self.doesRenderWhenResized {
                    self.renderURLImage()
                }
            }
        ]
    }
    
    private func showURLSpinner() {
        if let _ = self.spinner { return }
        
        let spinner = UIActivityIndicatorView(style: .gray)
        self.spinner = spinner
        
        spinner.startAnimating()
        
        view.addSubview(spinner)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    }
    
    private func hideURLSpinner() {
        guard let spinner = self.spinner else {
            return
        }
        
        spinner.removeFromSuperview()
        self.spinner = nil
    }
    
    public func renderURLImage() {
        var image = urlImage
        if let filter = urlImageFilter {
            image = filter(image)
        }
        view.image = image
    }
}

internal var exKey: UInt8 = 0

extension UIImageView {
    internal var ex: UIImageViewEx {
        get {
            if let ex = objc_getAssociatedObject(self, &exKey) as? UIImageViewEx {
                return ex
            }
            
            let ex = UIImageViewEx(view: self)
            self.ex = ex
            return ex
        }
        set {
            objc_setAssociatedObject(self, &exKey, newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public var url: URL? {
        get { return ex.url }
        set { ex.url = newValue }
    }
    
    public var urlImage: UIImage? {
        get { return ex.urlImage }
        set { ex.urlImage = newValue }
    }
    
    public var urlImageHandler: ((UIImage?) -> Void)? {
        get { return ex.urlImageHandler }
        set { ex.urlImageHandler = newValue }
    }
    
    public var isURLLoading: Bool {
        get { return ex.loader.isLoading }
    }
    
    public var isURLLoadingHandler: ((Bool) -> Void)? {
        get { return ex.isURLLoadingHandler }
        set { ex.isURLLoadingHandler = newValue }
    }
    
    @IBInspectable
    public var showsURLSpinner: Bool {
        get { return ex.showsURLSpinner }
        set { ex.showsURLSpinner = newValue }
    }
    
    public var urlImageFilter: ((UIImage?) -> UIImage?)? {
        get { return ex.urlImageFilter }
        set { ex.urlImageFilter = newValue }
    }
    
    public var doesRenderWhenResized: Bool {
        get { return ex.doesRenderWhenResized }
        set { ex.doesRenderWhenResized = newValue }
    }
    
    public func renderURLImage() {
        ex.renderURLImage()
    }
}
