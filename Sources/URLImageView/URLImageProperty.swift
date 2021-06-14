import UIKit

public final class URLImageProperty {
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
    
    public var image: UIImage? {
        get { return _image }
        set {
            _image = newValue
            
            render()
        }
    }
    
    private var _image: UIImage?
    
    public var imageHandler: ((UIImage?) -> Void)?
    public var imageFilter: ((UIImage?) -> UIImage?)?
    
    public var isLoading: Bool { return loader.isLoading }
    public var isLoadingHandler: ((Bool) -> Void)? {
        get { return loader.isLoadingHandler }
        set { loader.isLoadingHandler = newValue }
    }

    public var mustStoreCache: Bool {
        get { return loader.mustStoreCache }
        set { loader.mustStoreCache = newValue }
    }
    
    private let loader: URLImageLoader
    
    public init() {
        self.loader = URLImageLoader(callbackQueue: .main)
        
        loader.imageHandler = { [weak self] (image) in
            guard let self = self else { return }
            
            self.image = image
        }
    }
    
    public func render() {
        var image = self.image
        if let filter = imageFilter {
            image = filter(image)
        }
        imageHandler?(image)
    }
}
