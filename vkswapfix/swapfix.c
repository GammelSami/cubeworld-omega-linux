/*
 * VK_LAYER_CWO_swapchain_format: fixes swapped red/blue in Cube World Omega.
 *
 * The client creates its swapchain as R8G8B8A8 although X11/XWayland surfaces
 * (Mesa and NVIDIA) only offer B8G8R8A8; the driver accepts it anyway and the
 * X server reads the pixels as BGRX. If the surface does not list the
 * requested RGBA format, this layer creates the swapchain (and the image
 * views on its images) with the matching BGRA format instead.
 */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vulkan/vk_layer.h>
#include <vulkan/vulkan.h>

#define EXPORT __attribute__((visibility("default")))
#define MAX_OBJS 16
#define MAX_IMAGES 64

typedef struct {
    void *key;
    VkInstance instance;
    PFN_vkGetInstanceProcAddr gipa;
    PFN_vkDestroyInstance DestroyInstance;
    PFN_vkGetPhysicalDeviceSurfaceFormatsKHR GetSurfaceFormats;
} InstanceData;

typedef struct {
    void *key;
    VkDevice device;
    VkPhysicalDevice phys;
    InstanceData *inst;
    PFN_vkGetDeviceProcAddr gdpa;
    PFN_vkDestroyDevice DestroyDevice;
    PFN_vkCreateSwapchainKHR CreateSwapchain;
    PFN_vkDestroySwapchainKHR DestroySwapchain;
    PFN_vkGetSwapchainImagesKHR GetSwapchainImages;
    PFN_vkCreateImageView CreateImageView;
} DeviceData;

typedef struct {
    VkSwapchainKHR swapchain;
    VkFormat from, to;
    uint32_t count;
    VkImage images[MAX_IMAGES];
} SwapData;

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static InstanceData instances[MAX_OBJS];
static DeviceData devices[MAX_OBJS];
static SwapData swaps[MAX_OBJS];
static int verbose = -1;

#define KEY(h) (*(void **)(h))

static void logmsg(const char *fmt, const char *a, int b, int c)
{
    if (verbose < 0)
        verbose = getenv("CWO_VK_SWAPFIX_DEBUG") != NULL;
    if (verbose) {
        fprintf(stderr, "[cwo-swapfix] ");
        fprintf(stderr, fmt, a, b, c);
        fputc('\n', stderr);
    }
}

static InstanceData *find_instance(void *key)
{
    for (int i = 0; i < MAX_OBJS; i++)
        if (instances[i].key == key)
            return &instances[i];
    return NULL;
}

static DeviceData *find_device(void *key)
{
    for (int i = 0; i < MAX_OBJS; i++)
        if (devices[i].key == key)
            return &devices[i];
    return NULL;
}

static VkFormat bgra_for(VkFormat f)
{
    switch (f) {
    case VK_FORMAT_R8G8B8A8_UNORM: return VK_FORMAT_B8G8R8A8_UNORM;
    case VK_FORMAT_R8G8B8A8_SRGB: return VK_FORMAT_B8G8R8A8_SRGB;
    default: return VK_FORMAT_UNDEFINED;
    }
}

/* ---- instance ---- */

static VKAPI_ATTR VkResult VKAPI_CALL CreateInstance(const VkInstanceCreateInfo *ci,
                                                     const VkAllocationCallbacks *alloc, VkInstance *out)
{
    VkLayerInstanceCreateInfo *link = (VkLayerInstanceCreateInfo *)ci->pNext;
    while (link && !(link->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO && link->function == VK_LAYER_LINK_INFO))
        link = (VkLayerInstanceCreateInfo *)link->pNext;
    if (!link)
        return VK_ERROR_INITIALIZATION_FAILED;

    PFN_vkGetInstanceProcAddr gipa = link->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    link->u.pLayerInfo = link->u.pLayerInfo->pNext;
    PFN_vkCreateInstance next = (PFN_vkCreateInstance)gipa(VK_NULL_HANDLE, "vkCreateInstance");
    VkResult res = next(ci, alloc, out);
    if (res != VK_SUCCESS)
        return res;

    pthread_mutex_lock(&lock);
    InstanceData *d = find_instance(NULL);
    if (d) {
        d->key = KEY(*out);
        d->instance = *out;
        d->gipa = gipa;
        d->DestroyInstance = (PFN_vkDestroyInstance)gipa(*out, "vkDestroyInstance");
        d->GetSurfaceFormats = (PFN_vkGetPhysicalDeviceSurfaceFormatsKHR)gipa(*out, "vkGetPhysicalDeviceSurfaceFormatsKHR");
    }
    pthread_mutex_unlock(&lock);
    return VK_SUCCESS;
}

static VKAPI_ATTR void VKAPI_CALL DestroyInstance(VkInstance instance, const VkAllocationCallbacks *alloc)
{
    pthread_mutex_lock(&lock);
    InstanceData *d = find_instance(KEY(instance));
    PFN_vkDestroyInstance next = d ? d->DestroyInstance : NULL;
    if (d)
        memset(d, 0, sizeof(*d));
    pthread_mutex_unlock(&lock);
    if (next)
        next(instance, alloc);
}

static VKAPI_ATTR VkResult VKAPI_CALL CreateDevice(VkPhysicalDevice phys, const VkDeviceCreateInfo *ci,
                                                   const VkAllocationCallbacks *alloc, VkDevice *out)
{
    VkLayerDeviceCreateInfo *link = (VkLayerDeviceCreateInfo *)ci->pNext;
    while (link && !(link->sType == VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO && link->function == VK_LAYER_LINK_INFO))
        link = (VkLayerDeviceCreateInfo *)link->pNext;
    if (!link)
        return VK_ERROR_INITIALIZATION_FAILED;

    PFN_vkGetInstanceProcAddr gipa = link->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    PFN_vkGetDeviceProcAddr gdpa = link->u.pLayerInfo->pfnNextGetDeviceProcAddr;
    link->u.pLayerInfo = link->u.pLayerInfo->pNext;

    pthread_mutex_lock(&lock);
    InstanceData *inst = find_instance(KEY(phys));
    pthread_mutex_unlock(&lock);

    PFN_vkCreateDevice next = (PFN_vkCreateDevice)gipa(inst ? inst->instance : VK_NULL_HANDLE, "vkCreateDevice");
    VkResult res = next(phys, ci, alloc, out);
    if (res != VK_SUCCESS)
        return res;

    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(NULL);
    if (d) {
        d->key = KEY(*out);
        d->device = *out;
        d->phys = phys;
        d->inst = inst;
        d->gdpa = gdpa;
        d->DestroyDevice = (PFN_vkDestroyDevice)gdpa(*out, "vkDestroyDevice");
        d->CreateSwapchain = (PFN_vkCreateSwapchainKHR)gdpa(*out, "vkCreateSwapchainKHR");
        d->DestroySwapchain = (PFN_vkDestroySwapchainKHR)gdpa(*out, "vkDestroySwapchainKHR");
        d->GetSwapchainImages = (PFN_vkGetSwapchainImagesKHR)gdpa(*out, "vkGetSwapchainImagesKHR");
        d->CreateImageView = (PFN_vkCreateImageView)gdpa(*out, "vkCreateImageView");
    }
    pthread_mutex_unlock(&lock);
    return VK_SUCCESS;
}

/* ---- device ---- */

static VKAPI_ATTR void VKAPI_CALL DestroyDevice(VkDevice device, const VkAllocationCallbacks *alloc)
{
    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(KEY(device));
    PFN_vkDestroyDevice next = d ? d->DestroyDevice : NULL;
    if (d)
        memset(d, 0, sizeof(*d));
    pthread_mutex_unlock(&lock);
    if (next)
        next(device, alloc);
}

static int surface_lists(DeviceData *d, VkSurfaceKHR surface, VkFormat fmt)
{
    if (!d->inst || !d->inst->GetSurfaceFormats)
        return 1; /* cannot tell: leave the app alone */
    uint32_t n = 0;
    if (d->inst->GetSurfaceFormats(d->phys, surface, &n, NULL) != VK_SUCCESS || n == 0)
        return 1;
    VkSurfaceFormatKHR *f = calloc(n, sizeof(*f));
    if (!f)
        return 1;
    int found = 0;
    VkResult res = d->inst->GetSurfaceFormats(d->phys, surface, &n, f);
    if (res != VK_SUCCESS && res != VK_INCOMPLETE)
        found = 1;
    for (uint32_t i = 0; i < n && !found; i++)
        found = f[i].format == fmt;
    free(f);
    return found;
}

static VKAPI_ATTR VkResult VKAPI_CALL CreateSwapchainKHR(VkDevice device, const VkSwapchainCreateInfoKHR *ci,
                                                         const VkAllocationCallbacks *alloc, VkSwapchainKHR *out)
{
    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(KEY(device));
    pthread_mutex_unlock(&lock);
    if (!d)
        return VK_ERROR_INITIALIZATION_FAILED;

    VkFormat to = bgra_for(ci->imageFormat);
    if (to == VK_FORMAT_UNDEFINED || surface_lists(d, ci->surface, ci->imageFormat) || !surface_lists(d, ci->surface, to))
        return d->CreateSwapchain(device, ci, alloc, out);

    VkSwapchainCreateInfoKHR fixed = *ci;
    fixed.imageFormat = to;
    VkResult res = d->CreateSwapchain(device, &fixed, alloc, out);
    logmsg("swapchain format %s%d -> %d", "", ci->imageFormat, to);
    if (res != VK_SUCCESS)
        return res;

    pthread_mutex_lock(&lock);
    for (int i = 0; i < MAX_OBJS; i++)
        if (!swaps[i].swapchain) {
            memset(&swaps[i], 0, sizeof(swaps[i]));
            swaps[i].swapchain = *out;
            swaps[i].from = ci->imageFormat;
            swaps[i].to = to;
            break;
        }
    pthread_mutex_unlock(&lock);
    return res;
}

static VKAPI_ATTR void VKAPI_CALL DestroySwapchainKHR(VkDevice device, VkSwapchainKHR swapchain,
                                                      const VkAllocationCallbacks *alloc)
{
    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(KEY(device));
    for (int i = 0; i < MAX_OBJS; i++)
        if (swapchain && swaps[i].swapchain == swapchain)
            memset(&swaps[i], 0, sizeof(swaps[i]));
    pthread_mutex_unlock(&lock);
    if (d)
        d->DestroySwapchain(device, swapchain, alloc);
}

static VKAPI_ATTR VkResult VKAPI_CALL GetSwapchainImagesKHR(VkDevice device, VkSwapchainKHR swapchain,
                                                            uint32_t *count, VkImage *images)
{
    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(KEY(device));
    pthread_mutex_unlock(&lock);
    if (!d)
        return VK_ERROR_INITIALIZATION_FAILED;
    VkResult res = d->GetSwapchainImages(device, swapchain, count, images);
    if (images && (res == VK_SUCCESS || res == VK_INCOMPLETE)) {
        pthread_mutex_lock(&lock);
        for (int i = 0; i < MAX_OBJS; i++)
            if (swaps[i].swapchain == swapchain) {
                uint32_t n = *count < MAX_IMAGES ? *count : MAX_IMAGES;
                memcpy(swaps[i].images, images, n * sizeof(VkImage));
                swaps[i].count = n;
            }
        pthread_mutex_unlock(&lock);
    }
    return res;
}

static VKAPI_ATTR VkResult VKAPI_CALL CreateImageView(VkDevice device, const VkImageViewCreateInfo *ci,
                                                      const VkAllocationCallbacks *alloc, VkImageView *out)
{
    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(KEY(device));
    VkFormat to = VK_FORMAT_UNDEFINED;
    for (int i = 0; i < MAX_OBJS && to == VK_FORMAT_UNDEFINED; i++)
        if (swaps[i].swapchain && ci->format == swaps[i].from)
            for (uint32_t j = 0; j < swaps[i].count; j++)
                if (swaps[i].images[j] == ci->image) {
                    to = swaps[i].to;
                    break;
                }
    pthread_mutex_unlock(&lock);
    if (!d)
        return VK_ERROR_INITIALIZATION_FAILED;
    if (to == VK_FORMAT_UNDEFINED)
        return d->CreateImageView(device, ci, alloc, out);
    VkImageViewCreateInfo fixed = *ci;
    fixed.format = to;
    return d->CreateImageView(device, &fixed, alloc, out);
}

/* ---- dispatch ---- */

static PFN_vkVoidFunction device_hook(const char *name)
{
#define HOOK(fn) if (!strcmp(name, "vk" #fn)) return (PFN_vkVoidFunction)fn;
    HOOK(DestroyDevice)
    HOOK(CreateSwapchainKHR)
    HOOK(DestroySwapchainKHR)
    HOOK(GetSwapchainImagesKHR)
    HOOK(CreateImageView)
#undef HOOK
    return NULL;
}

EXPORT VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL CWO_GetDeviceProcAddr(VkDevice device, const char *name);

EXPORT VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL CWO_GetInstanceProcAddr(VkInstance instance, const char *name)
{
    if (!strcmp(name, "vkGetInstanceProcAddr")) return (PFN_vkVoidFunction)CWO_GetInstanceProcAddr;
    if (!strcmp(name, "vkGetDeviceProcAddr")) return (PFN_vkVoidFunction)CWO_GetDeviceProcAddr;
    if (!strcmp(name, "vkCreateInstance")) return (PFN_vkVoidFunction)CreateInstance;
    if (!strcmp(name, "vkDestroyInstance")) return (PFN_vkVoidFunction)DestroyInstance;
    if (!strcmp(name, "vkCreateDevice")) return (PFN_vkVoidFunction)CreateDevice;
    PFN_vkVoidFunction hook = device_hook(name);
    if (hook)
        return hook;
    if (!instance)
        return NULL;
    pthread_mutex_lock(&lock);
    InstanceData *d = find_instance(KEY(instance));
    pthread_mutex_unlock(&lock);
    return d ? d->gipa(instance, name) : NULL;
}

EXPORT VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL CWO_GetDeviceProcAddr(VkDevice device, const char *name)
{
    if (!strcmp(name, "vkGetDeviceProcAddr")) return (PFN_vkVoidFunction)CWO_GetDeviceProcAddr;
    PFN_vkVoidFunction hook = device_hook(name);
    if (hook)
        return hook;
    pthread_mutex_lock(&lock);
    DeviceData *d = find_device(KEY(device));
    pthread_mutex_unlock(&lock);
    return d ? d->gdpa(device, name) : NULL;
}

EXPORT VKAPI_ATTR VkResult VKAPI_CALL CWO_NegotiateLoaderLayerInterfaceVersion(VkNegotiateLayerInterface *v)
{
    if (v->loaderLayerInterfaceVersion > 2)
        v->loaderLayerInterfaceVersion = 2;
    v->pfnGetInstanceProcAddr = CWO_GetInstanceProcAddr;
    v->pfnGetDeviceProcAddr = CWO_GetDeviceProcAddr;
    v->pfnGetPhysicalDeviceProcAddr = NULL;
    return VK_SUCCESS;
}
