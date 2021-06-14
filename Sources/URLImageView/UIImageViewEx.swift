import UIKit

internal final class UIImageViewEx : ExProtocol {
    public unowned let view: UIImageView
    public let url: URLImageProperty
    public var urlImageHandler: ((UIImage?) -> Void)?
    public var isURLLoadingHandler: ((Bool) -> Void)?
    public var showsURLSpinner: Bool = false
    public var spinner: UIActivityIndicatorView?
    
    public init(view: UIView) {
        self.view = view as! UIImageView
        self.url = URLImageProperty()

        url.isLoadingHandler = { [weak self] (isLoading) in
            guard let self = self else { return }
            
            if isLoading, self.showsURLSpinner {
                self.view.showSpinnerIfNeed(spinner: &self.spinner)
            } else {
                self.view.hideSpinner(spinner: &self.spinner)
            }
            
            self.isURLLoadingHandler?(isLoading)
        }
        url.imageHandler = { [weak self] (image) in
            guard let self = self else { return }
            
            self.view.image = image
            
            self.urlImageHandler?(image)
        }
    }
}

extension UIImageView {
    internal var ex: UIImageViewEx { return exImpl() }
    
    public var url: URL? {
        get { return ex.url.url }
        set { ex.url.url = newValue }
    }
    
    public var urlImage: UIImage? {
        get { return ex.url.image }
        set { ex.url.image = newValue }
    }
    
    public var urlImageHandler: ((UIImage?) -> Void)? {
        get { return ex.urlImageHandler }
        set { ex.urlImageHandler = newValue }
    }
    
    public var urlImageFilter: ((UIImage?) -> UIImage?)? {
        get { return ex.url.imageFilter }
        set { ex.url.imageFilter = newValue }
    }
    
    public var isURLLoading: Bool {
        get { return ex.url.isLoading }
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

    public func renderURLImage() {
        ex.url.render()
    }

    public var mustStoreURLImageCache: Bool {
        get { return ex.url.mustStoreCache }
        set { ex.url.mustStoreCache = newValue }
    }
}
